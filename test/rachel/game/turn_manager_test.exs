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

  describe "apply_skip/1" do
    test "skips current player when pending_skips > 0", %{game: game} do
      game = %{game | pending_skips: 1, current_player_index: 0}

      result = TurnManager.apply_skip(game)

      # With 1 skip: advance 1 + skip 1 = 2 steps from index 0, lands on index 2
      assert result.current_player_index == 2
      assert result.pending_skips == 0
      assert result.nominated_suit == nil
    end

    test "skips multiple players", %{game: game} do
      game = %{game | pending_skips: 2, current_player_index: 0}

      result = TurnManager.apply_skip(game)

      # With 2 skips: advance 1 + skip 2 = 3 steps from index 0
      # Lands on index 3, but player 4 (index 3) has won, so wraps to index 0
      assert result.current_player_index == 0
      assert result.pending_skips == 0
    end

    test "clears nominated_suit after applying skips", %{game: game} do
      game = %{game | pending_skips: 1, nominated_suit: :hearts, current_player_index: 0}

      result = TurnManager.apply_skip(game)

      assert result.nominated_suit == nil
      assert result.pending_skips == 0
    end

    test "does nothing when pending_skips is 0", %{game: game} do
      game = %{game | pending_skips: 0, current_player_index: 0}

      result = TurnManager.apply_skip(game)

      # Game unchanged
      assert result.current_player_index == 0
      assert result.pending_skips == 0
    end

    test "does nothing when pending_skips is nil", %{game: game} do
      game = %{game | pending_skips: nil, current_player_index: 1}

      result = TurnManager.apply_skip(game)

      # Game unchanged
      assert result.current_player_index == 1
    end

    test "handles counter-clockwise skips", %{game: game} do
      game = %{
        game
        | pending_skips: 1,
          current_player_index: 0,
          direction: :counter_clockwise
      }

      result = TurnManager.apply_skip(game)

      # From 0, counter-clockwise skip 1 goes to index 2 (skipping 3 which has won)
      assert result.current_player_index == 2
      assert result.pending_skips == 0
    end

    test "skips over winners during skip application", %{game: game} do
      game = %{game | pending_skips: 3, current_player_index: 0}

      result = TurnManager.apply_skip(game)

      # Skip 3 from index 0 lands on index 3, but that player won, so should be index 0
      assert result.current_player_index == 0
    end
  end

  describe "clear_nomination/1" do
    test "clears the nominated suit", %{game: game} do
      game = %{game | nominated_suit: :hearts}

      result = TurnManager.clear_nomination(game)

      assert result.nominated_suit == nil
    end

    test "works when suit already nil", %{game: game} do
      game = %{game | nominated_suit: nil}

      result = TurnManager.clear_nomination(game)

      assert result.nominated_suit == nil
    end

    test "preserves all other game state", %{game: game} do
      game = %{game | nominated_suit: :spades, pending_skips: 2}

      result = TurnManager.clear_nomination(game)

      assert result.nominated_suit == nil
      assert result.pending_skips == 2
      assert result.current_player_index == game.current_player_index
      assert result.players == game.players
    end
  end

  describe "clear_skips/1" do
    test "clears pending skips to 0", %{game: game} do
      game = %{game | pending_skips: 3}

      result = TurnManager.clear_skips(game)

      assert result.pending_skips == 0
    end

    test "works when skips already 0", %{game: game} do
      game = %{game | pending_skips: 0}

      result = TurnManager.clear_skips(game)

      assert result.pending_skips == 0
    end

    test "preserves all other game state", %{game: game} do
      game = %{game | pending_skips: 5, nominated_suit: :clubs}

      result = TurnManager.clear_skips(game)

      assert result.pending_skips == 0
      assert result.nominated_suit == :clubs
      assert result.current_player_index == game.current_player_index
      assert result.players == game.players
    end
  end

  describe "consume_skip/1" do
    test "reduces pending_skips by 1", %{game: game} do
      game = %{game | pending_skips: 3}

      result = TurnManager.consume_skip(game)

      assert result.pending_skips == 2
    end

    test "reduces from 1 to 0", %{game: game} do
      game = %{game | pending_skips: 1}

      result = TurnManager.consume_skip(game)

      assert result.pending_skips == 0
    end

    test "stays at 0 when already 0", %{game: game} do
      game = %{game | pending_skips: 0}

      result = TurnManager.consume_skip(game)

      assert result.pending_skips == 0
    end

    test "never goes below 0", %{game: game} do
      game = %{game | pending_skips: 0}

      result = TurnManager.consume_skip(game)

      assert result.pending_skips == 0
      refute result.pending_skips < 0
    end

    test "preserves all other game state", %{game: game} do
      game = %{game | pending_skips: 2, nominated_suit: :diamonds}

      result = TurnManager.consume_skip(game)

      assert result.pending_skips == 1
      assert result.nominated_suit == :diamonds
      assert result.current_player_index == game.current_player_index
      assert result.players == game.players
    end

    test "can be called multiple times", %{game: game} do
      game = %{game | pending_skips: 5}

      result =
        game
        |> TurnManager.consume_skip()
        |> TurnManager.consume_skip()
        |> TurnManager.consume_skip()

      assert result.pending_skips == 2
    end
  end

  describe "edge cases and integration" do
    test "all players have won scenario", %{game: game} do
      players = Enum.map(game.players, &Map.put(&1, :status, :won))
      game = %{game | players: players, current_player_index: 0}

      # Should still advance but with all won, lands on next index after checking all
      result = TurnManager.advance_turn(game)

      # Advances one step, lands on index 1 (even though won, no active players exist)
      assert result.current_player_index == 1
    end

    test "single player remaining", %{game: game} do
      # Mark all but one player as won
      players =
        game.players
        |> List.update_at(0, &Map.put(&1, :status, :won))
        |> List.update_at(1, &Map.put(&1, :status, :won))
        |> List.update_at(3, &Map.put(&1, :status, :won))

      game = %{game | players: players}

      assert TurnManager.should_end?(game)
    end

    test "direction reversal affects turn order" do
      players = [
        %{id: "p1", hand: [1], status: :playing},
        %{id: "p2", hand: [2], status: :playing},
        %{id: "p3", hand: [3], status: :playing}
      ]

      game = %{
        players: players,
        current_player_index: 1,
        direction: :clockwise,
        pending_skips: 0,
        nominated_suit: nil,
        winners: []
      }

      # Clockwise from 1 goes to 2
      clockwise_result = TurnManager.advance_turn(game)
      assert clockwise_result.current_player_index == 2

      # Counter-clockwise from 1 goes to 0
      counter_game = %{game | direction: :counter_clockwise}
      counter_result = TurnManager.advance_turn(counter_game)
      assert counter_result.current_player_index == 0
    end

    test "complex skip scenario with wrap-around" do
      players = [
        %{id: "p1", hand: [1], status: :playing},
        %{id: "p2", hand: [2], status: :playing},
        %{id: "p3", hand: [3], status: :playing},
        %{id: "p4", hand: [4], status: :playing}
      ]

      game = %{
        players: players,
        current_player_index: 3,
        direction: :clockwise,
        pending_skips: 5,
        nominated_suit: nil,
        winners: []
      }

      result = TurnManager.advance_turn(game)

      # From 3, skip 5 players clockwise: lands on (3+1+5) % 4 = 1
      assert result.current_player_index == 1
      assert result.pending_skips == 0
    end

    test "nomination persists through turn with skip" do
      game = %{
        players: [
          %{id: "p1", hand: [1], status: :playing},
          %{id: "p2", hand: [2], status: :playing},
          %{id: "p3", hand: [3], status: :playing}
        ],
        current_player_index: 0,
        direction: :clockwise,
        pending_skips: 1,
        nominated_suit: :diamonds,
        winners: []
      }

      result = TurnManager.advance_turn(game)

      # Nomination should persist
      assert result.nominated_suit == :diamonds
      # But skips should be cleared
      assert result.pending_skips == 0
    end
  end
end
