defmodule Rachel.Game.IntegrationBugHuntTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{Card, GameError, GameState}

  describe "Bug hunting - specific scenarios" do
    test "Ace nomination should work" do
      players = [
        %{id: "p1", name: "Player 1", hand: [Card.new(:hearts, 14)], status: :playing},
        %{id: "p2", name: "Player 2", hand: [Card.new(:spades, 5)], status: :playing}
      ]

      game = %GameState{
        players: players,
        # Hearts 10 on top
        discard_pile: [Card.new(:hearts, 10)],
        deck: [Card.new(:clubs, 3), Card.new(:diamonds, 4)],
        current_player_index: 0,
        status: :playing
      }

      # Player 1 plays Ace of Hearts, nominates spades
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 14)], :spades)

      # Should have nominated spades
      assert game.nominated_suit == :spades
      # Turn should advance
      assert game.current_player_index == 1
    end

    test "Card matching with suit/rank" do
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [
            # Matches suit
            Card.new(:hearts, 12),
            # Matches rank
            Card.new(:clubs, 10),
            # Matches neither
            Card.new(:spades, 7)
          ],
          status: :playing
        }
      ]

      game = %GameState{
        players: players,
        # Hearts 10 on top
        discard_pile: [Card.new(:hearts, 10)],
        deck: [Card.new(:clubs, 3)],
        current_player_index: 0,
        status: :playing
      }

      # Hearts 12 should work (matches suit)
      {:ok, game1} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])
      assert hd(game1.discard_pile) == Card.new(:hearts, 12)

      # Reset and try rank match
      {:ok, game2} = GameState.play_cards(game, "p1", [Card.new(:clubs, 10)])
      assert hd(game2.discard_pile) == Card.new(:clubs, 10)

      # Spades 7 should fail
      result = GameState.play_cards(game, "p1", [Card.new(:spades, 7)])
      assert {:error, %GameError{type: :invalid_play}} = result
    end

    test "Turn advancement with direction" do
      players = [
        %{id: "p1", name: "Player 1", hand: [Card.new(:hearts, 12)], status: :playing},
        %{id: "p2", name: "Player 2", hand: [Card.new(:hearts, 8)], status: :playing},
        %{id: "p3", name: "Player 3", hand: [Card.new(:hearts, 9)], status: :playing},
        %{id: "p4", name: "Player 4", hand: [Card.new(:hearts, 7)], status: :playing}
      ]

      game = %GameState{
        players: players,
        discard_pile: [Card.new(:hearts, 10)],
        deck: [Card.new(:clubs, 3)],
        current_player_index: 0,
        direction: :clockwise,
        status: :playing
      }

      # Player 1 plays Queen (reverses direction)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])
      assert game.direction == :counter_clockwise
      # Should go to Player 4 (index 3) in counter-clockwise
      assert game.current_player_index == 3

      # Player 4 plays 7 (skip card)
      {:ok, game} = GameState.play_cards(game, "p4", [Card.new(:hearts, 7)])
      # 7 causes a skip, so should skip Player 3 and go to Player 2 (index 1) in counter-clockwise
      assert game.current_player_index == 1
    end

    test "Skip handling" do
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [Card.new(:hearts, 7), Card.new(:diamonds, 3)],
          status: :playing
        },
        %{id: "p2", name: "Player 2", hand: [Card.new(:spades, 5)], status: :playing},
        %{id: "p3", name: "Player 3", hand: [Card.new(:clubs, 6)], status: :playing}
      ]

      game = %GameState{
        players: players,
        discard_pile: [Card.new(:hearts, 10)],
        deck: [Card.new(:diamonds, 3)],
        current_player_index: 0,
        status: :playing
      }

      # Player 1 plays 7 (skip)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 7)])
      # Skip is applied immediately during turn advancement
      assert game.pending_skips == 0
      # Should skip Player 2 and go to Player 3 (index 2)
      assert game.current_player_index == 2

      # Player 3 can now play normally
      # They cannot play matching cards, so they draw
      # Current player should be at index 2 (p3)
      assert game.current_player_index == 2
      current_player = Enum.at(game.players, 2)
      assert current_player.id == "p3"

      {:ok, game} = GameState.draw_cards(game, "p3", :cannot_play)

      # After drawing, should advance to next player (index 0)
      assert game.current_player_index == 0
      assert game.pending_skips == 0
    end

    test "Simple Black Jack attack and Red Jack counter" do
      players = [
        %{id: "p1", name: "Player 1", hand: [Card.new(:spades, 11)], status: :playing},
        %{id: "p2", name: "Player 2", hand: [Card.new(:hearts, 11)], status: :playing}
      ]

      game = %GameState{
        players: players,
        # Spades 10
        discard_pile: [Card.new(:spades, 10)],
        deck: [Card.new(:diamonds, 3), Card.new(:clubs, 4)],
        current_player_index: 0,
        status: :playing
      }

      # Player 1 plays Black Jack
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:spades, 11)])
      assert game.pending_attack == {:black_jacks, 5}
      assert game.current_player_index == 1

      # Player 2 plays Red Jack to cancel
      {:ok, game} = GameState.play_cards(game, "p2", [Card.new(:hearts, 11)])
      # Should be cancelled
      assert game.pending_attack == nil
    end
  end
end
