defmodule Rachel.Leaderboard do
  @moduledoc """
  Context for Elo-based leaderboard functionality.

  Handles rating calculations, updates, and leaderboard queries.
  """

  import Ecto.Query
  alias Rachel.Accounts.User
  alias Rachel.Leaderboard.RatingHistory
  alias Rachel.Repo

  # Elo calculation constants
  @provisional_k 32
  @established_k 16
  @provisional_threshold 30

  # Tier thresholds
  @tier_thresholds [
    {1500, "diamond"},
    {1300, "platinum"},
    {1100, "gold"},
    {900, "silver"},
    {0, "bronze"}
  ]

  @doc """
  Calculate expected score using Elo formula.
  Returns value between 0 and 1.
  """
  def calculate_expected_score(player_rating, opponent_rating) do
    1 / (1 + :math.pow(10, (opponent_rating - player_rating) / 400))
  end

  @doc """
  Calculate rating change for a single matchup.
  actual_score: 1.0 for win, 0.5 for draw, 0.0 for loss
  """
  def calculate_rating_change(player_rating, opponent_rating, actual_score, k_factor) do
    expected = calculate_expected_score(player_rating, opponent_rating)
    round(k_factor * (actual_score - expected))
  end

  @doc """
  Get K-factor based on games played.
  Provisional players (< 30 games) have higher K for faster adjustment.
  """
  def get_k_factor(games_played) when games_played < @provisional_threshold, do: @provisional_k
  def get_k_factor(_games_played), do: @established_k

  @doc """
  Calculate tier based on Elo rating.
  """
  def calculate_tier(rating) do
    Enum.find_value(@tier_thresholds, fn {threshold, tier} ->
      if rating >= threshold, do: tier
    end)
  end

  @doc """
  Calculate rating changes for all players in a multiplayer game.

  Uses pairwise comparison: each player pair is treated as a 1v1 match.
  Position determines who "beat" whom (lower position = better finish).

  Input: List of %{user_id, rating, games_played, position}
  Output: List of %{user_id, rating_change, new_rating, new_tier, opponents_count}
  """
  def calculate_pairwise_changes(players) when length(players) < 2, do: []

  def calculate_pairwise_changes(players) do
    Enum.map(players, &calculate_player_rating_change(&1, players))
  end

  defp calculate_player_rating_change(player, all_players) do
    k = get_k_factor(player.games_played)
    opponents = Enum.reject(all_players, &(&1.user_id == player.user_id))
    total_change = calculate_total_change(player, opponents, k)
    new_rating = max(0, player.rating + total_change)

    %{
      user_id: player.user_id,
      rating_before: player.rating,
      rating_change: total_change,
      new_rating: new_rating,
      new_tier: calculate_tier(new_rating),
      game_position: player.position,
      opponents_count: length(opponents)
    }
  end

  defp calculate_total_change(player, opponents, k) do
    opponents
    |> Enum.map(&rating_change_for_opponent(player, &1, k))
    |> Enum.sum()
  end

  defp rating_change_for_opponent(player, opponent, k) do
    actual_score = if player.position < opponent.position, do: 1.0, else: 0.0
    calculate_rating_change(player.rating, opponent.rating, actual_score, k)
  end

  @doc """
  Process game results and update all player ratings.

  Takes a game_id and list of %{user_id, position} for human players.
  Updates ratings in a transaction.
  """
  def process_game_results(_game_id, results) when length(results) < 2 do
    {:error, :not_enough_players}
  end

  def process_game_results(game_id, results) do
    # Load current user data
    user_ids = Enum.map(results, & &1.user_id)

    users =
      User
      |> where([u], u.id in ^user_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    # Build player data for calculation
    players =
      Enum.map(results, fn result ->
        user = users[result.user_id]

        %{
          user_id: result.user_id,
          rating: user.elo_rating,
          games_played: user.elo_games_played,
          position: result.position
        }
      end)

    # Calculate rating changes
    changes = calculate_pairwise_changes(players)

    # Apply changes in transaction
    Repo.transaction(fn ->
      Enum.map(changes, fn change ->
        user = users[change.user_id]

        # Update user rating
        {:ok, _} =
          user
          |> User.elo_changeset(%{
            elo_rating: change.new_rating,
            elo_games_played: user.elo_games_played + 1,
            elo_tier: change.new_tier
          })
          |> Repo.update()

        # Record history
        {:ok, _} =
          %RatingHistory{}
          |> RatingHistory.changeset(%{
            user_id: change.user_id,
            game_id: game_id,
            rating_before: change.rating_before,
            rating_after: change.new_rating,
            rating_change: change.rating_change,
            game_position: change.game_position,
            opponents_count: change.opponents_count
          })
          |> Repo.insert()

        change
      end)
    end)
  end

  @doc """
  Get leaderboard - top players by Elo rating.
  Only includes players with at least 1 ranked game.
  """
  def get_leaderboard(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    User
    |> where([u], u.elo_games_played > 0)
    |> order_by([u], desc: u.elo_rating)
    |> limit(^limit)
    |> select([u], %{
      id: u.id,
      username: u.username,
      display_name: u.display_name,
      avatar_id: u.avatar_id,
      elo_rating: u.elo_rating,
      elo_games_played: u.elo_games_played,
      elo_tier: u.elo_tier
    })
    |> Repo.all()
  end

  @doc """
  Get a user's rank on the leaderboard.
  Returns nil if user has no ranked games.
  """
  def get_user_rank(user_id) do
    user = Repo.get(User, user_id)

    if user && user.elo_games_played > 0 do
      User
      |> where([u], u.elo_games_played > 0)
      |> where([u], u.elo_rating > ^user.elo_rating)
      |> select([u], count(u.id))
      |> Repo.one()
      |> Kernel.+(1)
    end
  end

  @doc """
  Get rating history for a user.
  """
  def get_rating_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    RatingHistory
    |> where([h], h.user_id == ^user_id)
    |> order_by([h], desc: h.inserted_at, desc: h.id)
    |> limit(^limit)
    |> Repo.all()
  end
end
