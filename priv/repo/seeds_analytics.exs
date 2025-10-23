# Analytics sample data seed script
# Run with: mix run priv/repo/seeds_analytics.exs

alias Rachel.Repo
alias Rachel.Analytics.{GameStat, CardPlayStat, CardDrawStat}

IO.puts("Seeding analytics sample data...")

# Helper to generate random dates in the past 30 days
defmodule DateHelper do
  def random_datetime_in_last_n_days(days) do
    now = DateTime.utc_now()
    seconds_ago = :rand.uniform(days * 24 * 60 * 60)
    DateTime.add(now, -seconds_ago, :second)
  end
end

# Sample game IDs
game_ids = for i <- 1..50, do: "game-#{i}"

# Create sample game stats
IO.puts("Creating sample game statistics...")

for game_id <- game_ids do
  player_count = Enum.random([2, 3, 4, 5, 6])
  ai_count = Enum.random(0..player_count)
  started_at = DateHelper.random_datetime_in_last_n_days(30)

  # Some games are finished, some abandoned
  finished? = :rand.uniform() > 0.1
  abandoned? = not finished? and :rand.uniform() > 0.7

  duration_seconds = if finished?, do: Enum.random(300..1800), else: nil
  total_turns = if finished?, do: Enum.random(20..100), else: nil
  finished_at = if finished?, do: DateTime.add(started_at, duration_seconds || 0, :second), else: nil

  winner_type = if finished? do
    Enum.random(["user", "anonymous", "ai"])
  else
    nil
  end

  winner_ai_difficulty = if winner_type == "ai" do
    Enum.random(["easy", "medium", "hard"])
  else
    nil
  end

  %GameStat{}
  |> GameStat.changeset(%{
    game_id: game_id,
    started_at: started_at,
    finished_at: finished_at,
    duration_seconds: duration_seconds,
    total_turns: total_turns,
    player_count: player_count,
    ai_count: ai_count,
    winner_type: winner_type,
    winner_ai_difficulty: winner_ai_difficulty,
    abandoned: abandoned?,
    deck_count: 1
  })
  |> Repo.insert!()
end

IO.puts("Created #{length(game_ids)} game statistics")

# Create sample card play stats
IO.puts("Creating sample card play statistics...")

cards_data = [
  %{"suit" => "hearts", "rank" => "ace"},
  %{"suit" => "diamonds", "rank" => "ace"},
  %{"suit" => "clubs", "rank" => "jack"},
  %{"suit" => "spades", "rank" => "jack"},
  %{"suit" => "hearts", "rank" => "queen"},
  %{"suit" => "diamonds", "rank" => "2"},
  %{"suit" => "clubs", "rank" => "7"},
  %{"suit" => "hearts", "rank" => "king"}
]

play_count = 0

for game_id <- Enum.take(game_ids, 30) do
  # Each game has 20-50 card plays
  num_plays = Enum.random(20..50)

  for turn <- 1..num_plays do
    player_type = Enum.random(["user", "anonymous", "ai"])
    ai_difficulty = if player_type == "ai", do: Enum.random(["easy", "medium", "hard"]), else: nil

    # 20% chance of stacking
    was_stacked = :rand.uniform() > 0.8
    stack_size = if was_stacked, do: Enum.random(2..4), else: 1

    cards_played =
      if was_stacked do
        card = Enum.random(cards_data)
        %{"cards" => Enum.map(1..stack_size, fn _ -> card end)}
      else
        %{"cards" => [Enum.random(cards_data)]}
      end

    nominated_suit =
      if Enum.any?(cards_played["cards"], &(&1["rank"] == "ace")) do
        Enum.random(["hearts", "diamonds", "clubs", "spades"])
      else
        nil
      end

    # Last play might result in win
    resulted_in_win = turn == num_plays and :rand.uniform() > 0.5

    %CardPlayStat{}
    |> CardPlayStat.changeset(%{
      game_id: game_id,
      player_type: player_type,
      ai_difficulty: ai_difficulty,
      turn_number: turn,
      cards_played: cards_played,
      was_stacked: was_stacked,
      stack_size: stack_size,
      nominated_suit: nominated_suit,
      resulted_in_win: resulted_in_win,
      played_at: DateHelper.random_datetime_in_last_n_days(30)
    })
    |> Repo.insert!()

    play_count = play_count + 1
  end
end

IO.puts("Created #{play_count} card play statistics")

# Create sample card draw stats
IO.puts("Creating sample card draw statistics...")

draw_count = 0

for game_id <- Enum.take(game_ids, 30) do
  # Each game has 10-30 card draws
  num_draws = Enum.random(10..30)

  for turn <- 1..num_draws do
    player_type = Enum.random(["user", "anonymous", "ai"])
    ai_difficulty = if player_type == "ai", do: Enum.random(["easy", "medium", "hard"]), else: nil

    reason = Enum.random(["cannot_play", "attack_penalty", "voluntary"])

    {cards_drawn, attack_type} = case reason do
      "attack_penalty" ->
        attack = Enum.random(["2", "7", "black_jack"])
        cards = case attack do
          "2" -> 2
          "7" -> 1  # Skip turn, but might draw before skipping
          "black_jack" -> 5
        end
        {cards, attack}

      "cannot_play" ->
        {1, nil}

      "voluntary" ->
        {1, nil}
    end

    %CardDrawStat{}
    |> CardDrawStat.changeset(%{
      game_id: game_id,
      player_type: player_type,
      ai_difficulty: ai_difficulty,
      turn_number: turn,
      cards_drawn: cards_drawn,
      reason: reason,
      attack_type: attack_type,
      drawn_at: DateHelper.random_datetime_in_last_n_days(30)
    })
    |> Repo.insert!()

    draw_count = draw_count + 1
  end
end

IO.puts("Created #{draw_count} card draw statistics")

IO.puts("\n✅ Analytics sample data seeded successfully!")
IO.puts("Visit http://localhost:4000/analytics to view the dashboard")
