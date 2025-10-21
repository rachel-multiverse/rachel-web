defmodule Rachel.Game.TurnManagerTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.TurnManager

  setup do
    players = [
      %{id: "p1", name: "Player 1", hand: [1, 2, 3], status: :playing},
      %{id: "p2", name: "Player 2", hand: [4, 5], status: :playing},
      %{id: "p3", name: "Player 3", hand: [6], status: :playing},
      %{id: "p4", name: "Player 4", hand: [], status: :won}
    ]

    game = %{
      players: players,
      current_player_index: 0,
      direction: :clockwise,
      pending_skips: 0,
      nominated_suit: nil,
      winners: ["p4"]
    }

    {:ok, game: game}
  end

  describe "advance_turn/1" do
    test "advances to next player clockwise", %{game: game} do
      result = TurnManager.advance_turn(game)
      assert result.current_player_index == 1
      assert result.pending_skips == 0
      assert result.nominated_suit == nil
    end

    test "advances counter-clockwise", %{game: game} do
      game = %{game | direction: :counter_clockwise}
      result = TurnManager.advance_turn(game)
      # From index 0, going counter-clockwise would go to 3, but player 4 has won
      # So it skips to player 3 (index 2)
      assert result.current_player_index == 2
    end

    test "pending skips are applied during turn advancement", %{game: game} do
      game = %{game | pending_skips: 2}
      result = TurnManager.advance_turn(game)
      # With 2 skips from player 0: skip players 1 and 2, land on player 3
      # But player 3 (index 3) has status :won, so it wraps to player 0
      assert result.current_player_index == 0
      assert result.pending_skips == 0
    end

    test "skips over players who have won", %{game: game} do
      game = %{game | current_player_index: 2}
      result = TurnManager.advance_turn(game)
      # From index 2, next would be 3 but player 4 has won, so wrap to 0
      assert result.current_player_index == 0
    end

    test "preserves nominated suit for next player", %{game: game} do
      game = %{game | nominated_suit: :hearts}
      result = TurnManager.advance_turn(game)
      # Nominations persist for the next player
      assert result.nominated_suit == :hearts
    end

    test "handles wrap-around at end of players", %{game: game} do
      game = %{game | current_player_index: 3}
      result = TurnManager.advance_turn(game)
      # From index 3, wrap to 0
      assert result.current_player_index == 0
    end

    test "handles multiple winners correctly", %{game: game} do
      # Mark player 2 as also won
      players = List.update_at(game.players, 1, &Map.put(&1, :status, :won))
      game = %{game | players: players}

      result = TurnManager.advance_turn(game)
      # From 0, skip 1 (won), go to 2
      assert result.current_player_index == 2
    end
  end

  describe "should_end?/1" do
    test "returns false when multiple players still playing", %{game: game} do
      refute TurnManager.should_end?(game)
    end

    test "returns true when only one player still playing", %{game: game} do
      players =
        game.players
        |> List.update_at(1, &Map.put(&1, :status, :won))
        |> List.update_at(2, &Map.put(&1, :status, :won))

      game = %{game | players: players}
      assert TurnManager.should_end?(game)
    end

    test "returns true when no players still playing", %{game: game} do
      players = Enum.map(game.players, &Map.put(&1, :status, :won))
      game = %{game | players: players}
      assert TurnManager.should_end?(game)
    end
  end

  describe "check_winner/2" do
    test "marks player as winner when hand is empty", %{game: game} do
      players = List.update_at(game.players, 2, &Map.put(&1, :hand, []))
      game = %{game | players: players}

      result = TurnManager.check_winner(game, 2)

      winner = Enum.at(result.players, 2)
      assert winner.status == :won
      assert "p3" in result.winners
    end

    test "doesn't mark player as winner when hand has cards", %{game: game} do
      result = TurnManager.check_winner(game, 0)

      player = Enum.at(result.players, 0)
      assert player.status == :playing
      assert "p1" not in result.winners
    end

    test "appends to existing winners list", %{game: game} do
      players = List.update_at(game.players, 1, &Map.put(&1, :hand, []))
      game = %{game | players: players}

      result = TurnManager.check_winner(game, 1)

      assert result.winners == ["p4", "p2"]
    end
  end
end
