defmodule Rachel.Game.RedJackIntegrationTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{Card, GameState}

  describe "Red Jack cancellation in full game flow" do
    setup do
      # Set up a game with Black Jack attack pending
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [
            # Red Jack
            Card.new(:hearts, 11),
            # Another Red Jack
            Card.new(:diamonds, 11),
            Card.new(:hearts, 5)
          ],
          status: :playing
        },
        %{
          id: "p2",
          name: "Player 2",
          hand: [
            Card.new(:clubs, 8),
            Card.new(:spades, 9)
          ],
          status: :playing
        }
      ]

      game = %GameState{
        players: players,
        # Black Jack on top
        discard_pile: [Card.new(:spades, 11)],
        deck: Enum.map(1..20, fn _ -> Card.new(:hearts, 3) end),
        current_player_index: 0,
        status: :playing,
        # Two Black Jacks = 10 cards
        pending_attack: {:black_jacks, 10}
      }

      {:ok, game: game}
    end

    test "single Red Jack reduces Black Jack attack", %{game: game} do
      # Play one Red Jack
      {:ok, new_game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 11)])

      # Attack should be reduced from 10 to 5
      assert new_game.pending_attack == {:black_jacks, 5}
      # Card should be on discard pile
      assert hd(new_game.discard_pile) == Card.new(:hearts, 11)
      # Turn should advance (attack continues to next player)
      assert new_game.current_player_index == 1
    end

    test "two Red Jacks completely cancel Black Jack attack", %{game: game} do
      # Play both Red Jacks at once (stacking)
      red_jacks = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      {:ok, new_game} = GameState.play_cards(game, "p1", red_jacks)

      # Attack should be completely cancelled (10 - 10 = 0)
      assert new_game.pending_attack == nil
      # Cards should be on discard pile (in the order played)
      assert Enum.take(new_game.discard_pile, 2) == red_jacks
      # Turn should advance normally
      assert new_game.current_player_index == 1
    end

    test "Red Jacks can over-cancel (more reduction than attack)", %{game: game} do
      # Set smaller attack
      game = %{game | pending_attack: {:black_jacks, 5}}

      # Play both Red Jacks (10 reduction for 5 attack)
      red_jacks = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      {:ok, new_game} = GameState.play_cards(game, "p1", red_jacks)

      # Attack should be cancelled (can't go negative)
      assert new_game.pending_attack == nil
    end

    test "Red Jacks don't work against 2s attack", %{game: game} do
      # Change to 2s attack
      game = %{game | pending_attack: {:twos, 4}}

      # Try to play Red Jack - should fail validation
      result = GameState.play_cards(game, "p1", [Card.new(:hearts, 11)])
      assert {:error, :invalid_counter} = result
    end

    test "mixed cards with Red Jack don't work", %{game: game} do
      # Try to play Red Jack with another card (invalid stack)
      cards = [Card.new(:hearts, 11), Card.new(:hearts, 5)]
      result = GameState.play_cards(game, "p1", cards)
      assert {:error, :invalid_stack} = result
    end

    test "Red Jack played normally (no Black Jack attack)", %{game: game} do
      # Remove the Black Jack attack
      game = %{game | pending_attack: nil, discard_pile: [Card.new(:hearts, 10)]}

      # Play Red Jack as normal card (matches hearts)
      {:ok, new_game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 11)])

      # Should work as normal play
      assert new_game.pending_attack == nil
      assert hd(new_game.discard_pile) == Card.new(:hearts, 11)
      assert new_game.current_player_index == 1
    end

    test "Black Jack vs Red Jack creates no attack", %{game: game} do
      # No pending attack, play Black Jack then Red Jack
      game = %{game | pending_attack: nil, discard_pile: [Card.new(:spades, 10)]}

      # Add Black Jack to player's hand
      players =
        List.update_at(game.players, 0, fn p ->
          %{p | hand: p.hand ++ [Card.new(:spades, 11)]}
        end)

      game = %{game | players: players}

      # Play Black Jack (creates attack)
      {:ok, game2} = GameState.play_cards(game, "p1", [Card.new(:spades, 11)])
      assert game2.pending_attack == {:black_jacks, 5}

      # Next player plays Red Jack to cancel
      # Simulate turn back for testing
      game2 = %{game2 | current_player_index: 0}
      {:ok, game3} = GameState.play_cards(game2, "p1", [Card.new(:hearts, 11)])
      assert game3.pending_attack == nil
    end
  end

  describe "Red Jack stacking validation" do
    test "can stack multiple Red Jacks of same rank" do
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [
            Card.new(:hearts, 11),
            Card.new(:diamonds, 11)
          ],
          status: :playing
        }
      ]

      game = %GameState{
        players: players,
        discard_pile: [Card.new(:spades, 11)],
        current_player_index: 0,
        status: :playing,
        pending_attack: {:black_jacks, 15}
      }

      # Both Red Jacks have rank 11, so they can stack
      cards = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      {:ok, new_game} = GameState.play_cards(game, "p1", cards)

      # Should reduce attack by 10 (2 × 5)
      assert new_game.pending_attack == {:black_jacks, 5}
    end
  end
end
