defmodule Rachel.Leaderboard do
  @moduledoc """
  Context for Elo-based leaderboard functionality.

  Handles rating calculations, updates, and leaderboard queries.
  """

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
    players
    |> Enum.map(fn player ->
      k = get_k_factor(player.games_played)
      opponents = Enum.reject(players, & &1.user_id == player.user_id)

      total_change =
        opponents
        |> Enum.map(fn opponent ->
          actual_score = if player.position < opponent.position, do: 1.0, else: 0.0
          calculate_rating_change(player.rating, opponent.rating, actual_score, k)
        end)
        |> Enum.sum()

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
    end)
  end
end
