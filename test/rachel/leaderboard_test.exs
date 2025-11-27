defmodule Rachel.LeaderboardTest do
  use Rachel.DataCase, async: true

  alias Rachel.Leaderboard

  describe "calculate_expected_score/2" do
    test "returns 0.5 for equal ratings" do
      assert_in_delta Leaderboard.calculate_expected_score(1000, 1000), 0.5, 0.001
    end

    test "returns higher score for higher rated player" do
      score = Leaderboard.calculate_expected_score(1200, 1000)
      assert score > 0.5
      assert_in_delta score, 0.76, 0.01
    end

    test "returns lower score for lower rated player" do
      score = Leaderboard.calculate_expected_score(1000, 1200)
      assert score < 0.5
      assert_in_delta score, 0.24, 0.01
    end
  end

  describe "calculate_rating_change/4" do
    test "positive change for win against equal opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1000, 1.0, 32)
      assert change > 0
      assert_in_delta change, 16, 1
    end

    test "negative change for loss against equal opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1000, 0.0, 32)
      assert change < 0
      assert_in_delta change, -16, 1
    end

    test "smaller gain for beating lower rated opponent" do
      change = Leaderboard.calculate_rating_change(1200, 1000, 1.0, 32)
      assert change > 0
      assert change < 16
    end

    test "larger gain for beating higher rated opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1200, 1.0, 32)
      assert change > 0
      assert change > 16
    end
  end

  describe "get_k_factor/1" do
    test "returns 32 for provisional players (< 30 games)" do
      assert Leaderboard.get_k_factor(0) == 32
      assert Leaderboard.get_k_factor(29) == 32
    end

    test "returns 16 for established players (>= 30 games)" do
      assert Leaderboard.get_k_factor(30) == 16
      assert Leaderboard.get_k_factor(100) == 16
    end
  end

  describe "calculate_tier/1" do
    test "bronze for rating < 900" do
      assert Leaderboard.calculate_tier(899) == "bronze"
      assert Leaderboard.calculate_tier(0) == "bronze"
    end

    test "silver for rating 900-1099" do
      assert Leaderboard.calculate_tier(900) == "silver"
      assert Leaderboard.calculate_tier(1099) == "silver"
    end

    test "gold for rating 1100-1299" do
      assert Leaderboard.calculate_tier(1100) == "gold"
      assert Leaderboard.calculate_tier(1299) == "gold"
    end

    test "platinum for rating 1300-1499" do
      assert Leaderboard.calculate_tier(1300) == "platinum"
      assert Leaderboard.calculate_tier(1499) == "platinum"
    end

    test "diamond for rating >= 1500" do
      assert Leaderboard.calculate_tier(1500) == "diamond"
      assert Leaderboard.calculate_tier(2000) == "diamond"
    end
  end

  describe "calculate_pairwise_changes/1" do
    test "calculates changes for 2-player game" do
      players = [
        %{user_id: 1, rating: 1000, games_played: 10, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)

      # Winner should gain, loser should lose equal amount
      assert length(changes) == 2
      winner_change = Enum.find(changes, & &1.user_id == 1)
      loser_change = Enum.find(changes, & &1.user_id == 2)

      assert winner_change.rating_change > 0
      assert loser_change.rating_change < 0
      assert winner_change.rating_change == -loser_change.rating_change
    end

    test "calculates changes for 4-player game" do
      players = [
        %{user_id: 1, rating: 1000, games_played: 10, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2},
        %{user_id: 3, rating: 1000, games_played: 10, position: 3},
        %{user_id: 4, rating: 1000, games_played: 10, position: 4}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)

      assert length(changes) == 4

      # First place beats 3 opponents, should have highest gain
      first = Enum.find(changes, & &1.user_id == 1)
      last = Enum.find(changes, & &1.user_id == 4)

      assert first.rating_change > 0
      assert last.rating_change < 0
      assert first.rating_change > abs(last.rating_change) / 3
    end

    test "higher rated player gains less for expected win" do
      players = [
        %{user_id: 1, rating: 1400, games_played: 50, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)
      winner = Enum.find(changes, & &1.user_id == 1)

      # High rated player beating low rated = small gain
      assert winner.rating_change > 0
      assert winner.rating_change < 10
    end
  end

  describe "process_game_results/2" do
    setup do
      user1 = insert_user()
      user2 = insert_user()
      {:ok, user1: user1, user2: user2}
    end

    test "updates user ratings and creates history", %{user1: user1, user2: user2} do
      # Use nil for game_id since we're not creating an actual game record
      game_id = nil

      results = [
        %{user_id: user1.id, position: 1},
        %{user_id: user2.id, position: 2}
      ]

      {:ok, changes} = Leaderboard.process_game_results(game_id, results)

      assert length(changes) == 2

      # Verify user ratings updated
      updated_user1 = Rachel.Repo.get!(Rachel.Accounts.User, user1.id)
      updated_user2 = Rachel.Repo.get!(Rachel.Accounts.User, user2.id)

      assert updated_user1.elo_rating > 1000
      assert updated_user2.elo_rating < 1000
      assert updated_user1.elo_games_played == 1

      # Verify history created
      history = Rachel.Repo.all(Rachel.Leaderboard.RatingHistory)
      assert length(history) == 2
    end

    test "returns error for single player", %{user1: user1} do
      results = [%{user_id: user1.id, position: 1}]
      assert {:error, :not_enough_players} = Leaderboard.process_game_results("game", results)
    end

    test "handles tier promotion", %{user1: user1, user2: user2} do
      # Set user1 near tier boundary
      user1
      |> Ecto.Changeset.change(%{elo_rating: 1095})
      |> Rachel.Repo.update!()

      # Use nil for game_id since we're not creating an actual game record
      game_id = nil
      results = [
        %{user_id: user1.id, position: 1},
        %{user_id: user2.id, position: 2}
      ]

      {:ok, changes} = Leaderboard.process_game_results(game_id, results)

      winner_change = Enum.find(changes, & &1.user_id == user1.id)
      assert winner_change.new_tier == "gold"

      updated_user1 = Rachel.Repo.get!(Rachel.Accounts.User, user1.id)
      assert updated_user1.elo_tier == "gold"
    end
  end

  describe "get_leaderboard/1" do
    test "returns top players ordered by rating" do
      user1 = insert_user() |> set_rating(1200)
      user2 = insert_user() |> set_rating(1100)
      user3 = insert_user() |> set_rating(1300)

      leaderboard = Leaderboard.get_leaderboard(limit: 10)

      assert length(leaderboard) == 3
      assert hd(leaderboard).id == user3.id
      assert List.last(leaderboard).id == user2.id
    end

    test "respects limit" do
      for _ <- 1..5, do: insert_user() |> set_rating(1100)

      leaderboard = Leaderboard.get_leaderboard(limit: 3)
      assert length(leaderboard) == 3
    end

    test "only includes players with ranked games" do
      _no_games = insert_user()
      with_games = insert_user() |> set_rating(1100, 5)

      leaderboard = Leaderboard.get_leaderboard(limit: 10)

      assert length(leaderboard) == 1
      assert hd(leaderboard).id == with_games.id
    end
  end

  describe "get_user_rank/1" do
    test "returns rank for user with games" do
      user1 = insert_user() |> set_rating(1200, 5)
      user2 = insert_user() |> set_rating(1300, 5)
      _user3 = insert_user() |> set_rating(1100, 5)

      assert Leaderboard.get_user_rank(user1.id) == 2
      assert Leaderboard.get_user_rank(user2.id) == 1
    end

    test "returns nil for user with no ranked games" do
      user = insert_user()
      assert Leaderboard.get_user_rank(user.id) == nil
    end
  end

  describe "get_rating_history/2" do
    test "returns recent history for user" do
      user = insert_user()

      # Insert some history - records will have sequential IDs
      entries =
        for i <- 1..5 do
          %Rachel.Leaderboard.RatingHistory{}
          |> Rachel.Leaderboard.RatingHistory.changeset(%{
            user_id: user.id,
            rating_before: 1000 + (i - 1) * 10,
            rating_after: 1000 + i * 10,
            rating_change: 10
          })
          |> Rachel.Repo.insert!()
        end

      history = Leaderboard.get_rating_history(user.id, limit: 3)

      assert length(history) == 3

      # Most recent first means highest IDs (last inserted)
      # The query orders by desc: inserted_at, which should give us the last 3 inserted
      last_three_entries = Enum.take(entries, -3) |> Enum.reverse()
      last_three_ids = Enum.map(last_three_entries, & &1.id)
      history_ids = Enum.map(history, & &1.id)

      assert history_ids == last_three_ids
    end
  end

  # Test helpers
  defp insert_user do
    {:ok, user} =
      %Rachel.Accounts.User{}
      |> Rachel.Accounts.User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Rachel.Repo.insert()

    user
  end

  defp set_rating(user, rating, games \\ 1) do
    user
    |> Ecto.Changeset.change(%{
      elo_rating: rating,
      elo_games_played: games,
      elo_tier: Leaderboard.calculate_tier(rating)
    })
    |> Rachel.Repo.update!()
  end
end
