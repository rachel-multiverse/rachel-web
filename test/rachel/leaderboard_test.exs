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
end
