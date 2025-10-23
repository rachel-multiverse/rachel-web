defmodule Rachel.Analytics do
  @moduledoc """
  The Analytics context.

  Provides functions for recording and querying game analytics data.
  Events are captured asynchronously to avoid blocking game operations.
  """

  import Ecto.Query, warn: false
  alias Rachel.Repo
  alias Rachel.Analytics.{GameStat, CardPlayStat, CardDrawStat}

  ## Game Stats

  @doc """
  Records when a game starts.

  ## Examples

      iex> record_game_start("game-123", %{player_count: 4, ai_count: 2})
      {:ok, %GameStat{}}

  """
  def record_game_start(game_id, attrs) do
    %GameStat{}
    |> GameStat.changeset(
      attrs
      |> Map.put(:game_id, game_id)
      |> Map.put(:started_at, DateTime.utc_now())
    )
    |> Repo.insert()
  end

  @doc """
  Records when a game finishes.

  ## Examples

      iex> record_game_finish("game-123", %{
        winner_type: "ai",
        winner_ai_difficulty: "hard",
        total_turns: 45
      })
      {:ok, %GameStat{}}

  """
  def record_game_finish(game_id, attrs) do
    game_stat = Repo.get_by!(GameStat, game_id: game_id, finished_at: nil)
    finished_at = DateTime.utc_now()
    duration = DateTime.diff(finished_at, game_stat.started_at)

    game_stat
    |> GameStat.changeset(
      attrs
      |> Map.put(:finished_at, finished_at)
      |> Map.put(:duration_seconds, duration)
    )
    |> Repo.update()
  end

  @doc """
  Marks a game as abandoned.

  ## Examples

      iex> mark_game_abandoned("game-123")
      {:ok, %GameStat{}}

  """
  def mark_game_abandoned(game_id) do
    game_stat = Repo.get_by!(GameStat, game_id: game_id, finished_at: nil)

    game_stat
    |> GameStat.changeset(%{abandoned: true, finished_at: DateTime.utc_now()})
    |> Repo.update()
  end

  ## Card Play Stats

  @doc """
  Records a card play event.

  ## Examples

      iex> record_card_play("game-123", %{
        player_type: "ai",
        ai_difficulty: "medium",
        turn_number: 12,
        cards_played: [%{suit: "hearts", rank: "ace"}],
        nominated_suit: "diamonds"
      })
      {:ok, %CardPlayStat{}}

  """
  def record_card_play(game_id, attrs) do
    %CardPlayStat{}
    |> CardPlayStat.changeset(
      attrs
      |> Map.put(:game_id, game_id)
      |> Map.put(:played_at, DateTime.utc_now())
    )
    |> Repo.insert()
  end

  ## Card Draw Stats

  @doc """
  Records a card draw event.

  ## Examples

      iex> record_card_draw("game-123", %{
        player_type: "user",
        turn_number: 8,
        cards_drawn: 2,
        reason: "attack_penalty",
        attack_type: "2"
      })
      {:ok, %CardDrawStat{}}

  """
  def record_card_draw(game_id, attrs) do
    %CardDrawStat{}
    |> CardDrawStat.changeset(
      attrs
      |> Map.put(:game_id, game_id)
      |> Map.put(:drawn_at, DateTime.utc_now())
    )
    |> Repo.insert()
  end

  ## Analytics Queries

  @doc """
  Gets win rate statistics by player type.

  Returns a list of maps with winner_type, wins, and win_percentage.
  """
  def win_rates_by_player_type do
    query =
      from g in GameStat,
        where: not is_nil(g.finished_at) and g.abandoned == false,
        group_by: g.winner_type,
        select: %{
          winner_type: g.winner_type,
          wins: count(g.id),
          win_percentage: fragment("ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)")
        },
        order_by: [desc: count(g.id)]

    Repo.all(query)
  end

  @doc """
  Gets AI difficulty effectiveness statistics.

  Returns win counts and average metrics for AI wins by difficulty level.
  """
  def ai_difficulty_effectiveness do
    query =
      from g in GameStat,
        where:
          g.winner_type == "ai" and not is_nil(g.winner_ai_difficulty) and g.abandoned == false,
        group_by: g.winner_ai_difficulty,
        select: %{
          difficulty: g.winner_ai_difficulty,
          wins: count(g.id),
          avg_turns_to_win: fragment("ROUND(AVG(?), 2)", g.total_turns),
          avg_duration_seconds: fragment("ROUND(AVG(?), 2)", g.duration_seconds)
        },
        order_by: [desc: count(g.id)]

    Repo.all(query)
  end

  @doc """
  Gets the most played cards with their win rates.

  Returns a list of cards sorted by times played.
  """
  def most_played_cards(limit \\ 20) do
    query =
      from c in CardPlayStat,
        select: %{
          cards: c.cards_played,
          times_played: count(c.id),
          led_to_wins: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", c.resulted_in_win)),
          win_rate_percentage:
            fragment(
              "ROUND(SUM(CASE WHEN ? THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)",
              c.resulted_in_win
            )
        },
        group_by: c.cards_played,
        order_by: [desc: count(c.id)],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets card stacking frequency distribution.

  Returns how often cards are stacked and in what quantities.
  """
  def card_stacking_frequency do
    query =
      from c in CardPlayStat,
        where: c.was_stacked == true,
        group_by: c.stack_size,
        select: %{
          stack_size: c.stack_size,
          occurrences: count(c.id),
          percentage: fragment("ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)")
        },
        order_by: c.stack_size

    Repo.all(query)
  end

  @doc """
  Gets distribution of reasons for drawing cards.

  Returns statistics on why players draw cards (attacks, cannot play, etc).
  """
  def draw_reasons_distribution do
    query =
      from d in CardDrawStat,
        group_by: [d.reason, d.attack_type],
        select: %{
          reason: d.reason,
          attack_type: d.attack_type,
          total_cards_drawn: sum(d.cards_drawn),
          occurrences: count(d.id),
          avg_cards_per_draw: fragment("ROUND(AVG(?), 2)", d.cards_drawn)
        },
        order_by: [desc: sum(d.cards_drawn)]

    Repo.all(query)
  end

  @doc """
  Gets average game metrics by player count.

  Returns duration, turns, and other averages grouped by player count.
  """
  def avg_game_metrics_by_player_count do
    query =
      from g in GameStat,
        where: not is_nil(g.finished_at) and g.abandoned == false,
        group_by: g.player_count,
        select: %{
          player_count: g.player_count,
          games_played: count(g.id),
          avg_duration_seconds: fragment("ROUND(AVG(?), 2)", g.duration_seconds),
          avg_turns: fragment("ROUND(AVG(?), 2)", g.total_turns),
          avg_turns_per_player:
            fragment("ROUND(AVG(?::float / ?), 2)", g.total_turns, g.player_count)
        },
        order_by: g.player_count

    Repo.all(query)
  end

  @doc """
  Gets peak play times by hour of day for the last 30 days.

  Returns game start counts for each hour.
  """
  def peak_play_times do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query =
      from g in GameStat,
        where: g.started_at > ^thirty_days_ago,
        select: %{
          hour_of_day: fragment("EXTRACT(HOUR FROM ?)", g.started_at),
          games_started: count(g.id),
          unique_days: fragment("COUNT(DISTINCT DATE(?))", g.started_at)
        },
        group_by: fragment("EXTRACT(HOUR FROM ?)", g.started_at),
        order_by: fragment("EXTRACT(HOUR FROM ?)", g.started_at)

    Repo.all(query)
  end

  @doc """
  Gets total games played in the specified time period.

  ## Examples

      iex> total_games_played(days: 7)
      42

  """
  def total_games_played(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    query =
      from g in GameStat,
        where: g.started_at > ^start_date and not is_nil(g.finished_at),
        select: count(g.id)

    Repo.one(query)
  end

  @doc """
  Gets abandoned game rate as a percentage.
  """
  def abandoned_game_rate do
    query =
      from g in GameStat,
        select: %{
          total_games: count(g.id),
          abandoned_games: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", g.abandoned)),
          abandoned_rate:
            fragment(
              "ROUND(SUM(CASE WHEN ? THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)",
              g.abandoned
            )
        }

    Repo.one(query)
  end
end
