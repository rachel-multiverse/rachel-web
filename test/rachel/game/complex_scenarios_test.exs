defmodule Rachel.Game.ComplexScenariosTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{Card, GameState}

  describe "Complex multi-turn scenarios" do
    setup do
      # Create a 4-player game with specific cards for complex scenarios
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [
            # Queen (reverse)
            Card.new(:hearts, 12),
            # 7 (skip)
            Card.new(:spades, 7),
            # Black Jack (attack)
            Card.new(:clubs, 11),
            # Ace (nominate)
            Card.new(:hearts, 14),
            # 2 (attack)
            Card.new(:diamonds, 2)
          ],
          status: :playing
        },
        %{
          id: "p2",
          name: "Player 2",
          hand: [
            # Queen (reverse)
            Card.new(:diamonds, 12),
            # 7 (skip counter)
            Card.new(:hearts, 7),
            # Red Jack (cancel)
            Card.new(:hearts, 11),
            # 2 (counter)
            Card.new(:spades, 2),
            # Normal card
            Card.new(:clubs, 5)
          ],
          status: :playing
        },
        %{
          id: "p3",
          name: "Player 3",
          hand: [
            # Queen (reverse)
            Card.new(:clubs, 12),
            # 7 (skip)
            Card.new(:diamonds, 7),
            # Black Jack (attack)
            Card.new(:spades, 11),
            # 2 (counter)
            Card.new(:hearts, 2),
            # Normal card
            Card.new(:diamonds, 8)
          ],
          status: :playing
        },
        %{
          id: "p4",
          name: "Player 4",
          hand: [
            # Queen (reverse)
            Card.new(:spades, 12),
            # 7 (skip counter)
            Card.new(:clubs, 7),
            # Red Jack (cancel)
            Card.new(:diamonds, 11),
            # 2 (counter)
            Card.new(:clubs, 2),
            # Normal card
            Card.new(:spades, 9)
          ],
          status: :playing
        }
      ]

      game = %GameState{
        players: players,
        # Start with hearts 10
        discard_pile: [Card.new(:hearts, 10)],
        deck: Enum.map(1..40, fn i -> Card.new(:hearts, rem(i, 13) + 2) end),
        current_player_index: 0,
        status: :playing,
        direction: :clockwise,
        pending_attack: nil,
        pending_skips: 0,
        nominated_suit: nil
      }

      {:ok, game: game}
    end

    test "Queen + Skip + Attack combo maintains correct turn order", %{game: game} do
      # Player 1 plays Queen (reverse)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])
      assert game.direction == :counter_clockwise
      # Player 4 (counter-clockwise)
      assert game.current_player_index == 3

      # Player 4 plays Queen (reverses back to clockwise)
      {:ok, game} = GameState.play_cards(game, "p4", [Card.new(:spades, 12)])
      assert game.direction == :clockwise
      # Back to Player 1 (clockwise from 3)
      assert game.current_player_index == 0

      # Player 1 has no matching cards, must draw
      {:ok, game} = GameState.draw_cards(game, "p1", :cannot_play)
      # Player 2
      assert game.current_player_index == 1

      # Player 2 plays Queen (matches rank)
      {:ok, game} = GameState.play_cards(game, "p2", [Card.new(:diamonds, 12)])
      # Reverses again
      assert game.direction == :counter_clockwise
      # Player 1 (counter-clockwise from 1)
      assert game.current_player_index == 0
    end

    test "Ace nomination during attack sequence", %{game: game} do
      # Player 1 plays Ace, nominates spades
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 14)], :spades)
      assert game.nominated_suit == :spades
      assert game.current_player_index == 1

      # Player 2 must play spades or another Ace - plays spades 2 (creates attack)
      {:ok, game} = GameState.play_cards(game, "p2", [Card.new(:spades, 2)])
      assert game.pending_attack == {:twos, 2}
      # Should clear after turn
      assert game.nominated_suit == nil
      assert game.current_player_index == 2

      # Player 3 can counter with any 2
      {:ok, game} = GameState.play_cards(game, "p3", [Card.new(:hearts, 2)])
      # Stacks
      assert game.pending_attack == {:twos, 4}
      assert game.current_player_index == 3

      # Player 4 must counter or draw 4 cards
      {:ok, game} = GameState.play_cards(game, "p4", [Card.new(:clubs, 2)])
      # Stacks to 6
      assert game.pending_attack == {:twos, 6}
    end

    test "Multiple direction reversals with complex effects", %{game: game} do
      # Start: clockwise, Player 1's turn
      # Player 1 plays Queen (reverses to counter-clockwise)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])
      assert game.direction == :counter_clockwise
      # Player 4
      assert game.current_player_index == 3

      # Player 4 plays Queen (reverses back to clockwise)
      {:ok, game} = GameState.play_cards(game, "p4", [Card.new(:spades, 12)])
      assert game.direction == :clockwise
      # Back to Player 1
      assert game.current_player_index == 0

      # Player 1 plays 7 (skip)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:spades, 7)])
      # Skip is applied immediately, skipping Player 2
      assert game.pending_skips == 0
      # Player 3 (skipped Player 2)
      assert game.current_player_index == 2

      # Player 3 plays 7 
      {:ok, game} = GameState.play_cards(game, "p3", [Card.new(:diamonds, 7)])
      # Skip is applied immediately, skipping Player 4
      assert game.pending_skips == 0
      # Back to Player 1
      assert game.current_player_index == 0
    end

    test "Maximum stacking scenario", %{game: game} do
      # Set up a game where Player 1 has multiple of same rank
      players =
        List.update_at(game.players, 0, fn p ->
          %{
            p
            | hand: [
                Card.new(:hearts, 7),
                Card.new(:diamonds, 7),
                Card.new(:clubs, 7),
                # All four 7s!
                Card.new(:spades, 7)
              ]
          }
        end)

      game = %{game | players: players}

      # Player 1 plays all four 7s
      all_sevens = [
        Card.new(:hearts, 7),
        Card.new(:diamonds, 7),
        Card.new(:clubs, 7),
        Card.new(:spades, 7)
      ]

      {:ok, game} = GameState.play_cards(game, "p1", all_sevens)

      # Skips are applied immediately - skip 4 players
      # In 4-player game: from P1, skip P2, P3, P4, P1, land on P2
      # Applied immediately
      assert game.pending_skips == 0
      # Lands on Player 2
      assert game.current_player_index == 1

      # Player 2 can now play normally
      {:ok, game} = GameState.draw_cards(game, "p2", :cannot_play)
      # Player 3
      assert game.current_player_index == 2
      # All skips were already applied
      assert game.pending_skips == 0

      # Player 3 can play a 7
      {:ok, game} = GameState.play_cards(game, "p3", [Card.new(:diamonds, 7)])
      # Skip applied immediately, skipping Player 4
      assert game.pending_skips == 0
      # From Player 3, skip Player 4, would land on Player 1 but P1 won, so goes to Player 2
      assert game.current_player_index == 1
    end

    test "Deck exhaustion during complex attack sequence", %{game: game} do
      # Set up game with very small deck
      game = %{
        game
        | deck: [
            Card.new(:hearts, 3),
            Card.new(:spades, 4),
            # Only 3 cards left
            Card.new(:clubs, 5)
          ]
      }

      # Player 1 creates massive Black Jack attack - update discard to match
      players =
        List.update_at(game.players, 0, fn p ->
          # Two Black Jacks
          %{p | hand: [Card.new(:clubs, 11), Card.new(:spades, 11)]}
        end)

      # Compatible top card
      game = %{game | players: players, discard_pile: [Card.new(:clubs, 10)]}

      {:ok, game} =
        GameState.play_cards(game, "p1", [
          Card.new(:clubs, 11),
          Card.new(:spades, 11)
        ])

      # 2 * 5 = 10
      assert game.pending_attack == {:black_jacks, 10}

      # Player 2 cannot counter, must draw 10 cards but deck only has 3
      # This should trigger deck reshuffling
      {:ok, game} = GameState.draw_cards(game, "p2", :attack)

      # Should have reshuffled and drawn cards
      player2 = Enum.at(game.players, 1)
      # Should have drawn some cards
      assert length(player2.hand) >= 5

      # Deck should be reconstructed from discard pile
      total_cards =
        length(game.deck) + length(game.discard_pile) +
          Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))

      # Should have reasonable number of cards
      assert total_cards > 20

      # Attack should be cleared
      assert game.pending_attack == nil
    end

    test "Winning during complex effect chain", %{game: game} do
      # Set Player 1 to have only one card
      players =
        List.update_at(game.players, 0, fn p ->
          # Only a Queen
          %{p | hand: [Card.new(:hearts, 12)]}
        end)

      game = %{game | players: players}

      # Player 1 plays their last card (Queen)
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])

      # Should win and be marked as winner
      player1 = Enum.at(game.players, 0)
      assert player1.status == :won
      assert length(player1.hand) == 0
      assert "p1" in game.winners

      # Direction should still reverse
      assert game.direction == :counter_clockwise

      # Turn should advance to next active player (skip the winner)
      # Player 4 (counter-clockwise)
      assert game.current_player_index == 3

      # Winner should be skipped in future turns  
      {:ok, game} = GameState.play_cards(game, "p4", [Card.new(:spades, 12)])
      # Player 2 (clockwise from 3, skipping won Player 1)
      assert game.current_player_index == 1
    end
  end

  describe "Game state integrity checks" do
    setup do
      # Create a simple game for integrity testing
      players = [
        %{
          id: "p1",
          name: "Player 1",
          hand: [
            Card.new(:hearts, 12),
            Card.new(:clubs, 11),
            Card.new(:diamonds, 2)
          ],
          status: :playing
        },
        %{
          id: "p2",
          name: "Player 2",
          hand: [
            Card.new(:hearts, 11),
            Card.new(:spades, 7),
            Card.new(:clubs, 5)
          ],
          status: :playing
        }
      ]

      game = %GameState{
        players: players,
        discard_pile: [Card.new(:hearts, 10)],
        deck: Enum.map(1..20, fn i -> Card.new(:hearts, rem(i, 13) + 2) end),
        current_player_index: 0,
        status: :playing
      }

      {:ok, game: game}
    end

    test "Card count remains constant throughout complex game", %{game: game} do
      initial_total = count_all_cards(game)

      # Perform several complex moves
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 12)])
      {:ok, game} = GameState.play_cards(game, "p2", [Card.new(:hearts, 11)])
      {:ok, game} = GameState.play_cards(game, "p1", [Card.new(:clubs, 11)])
      # P2 draws due to Black Jack attack
      {:ok, game} = GameState.draw_cards(game, "p2", :attack)

      final_total = count_all_cards(game)
      assert initial_total == final_total
    end

    defp count_all_cards(game) do
      deck_count = length(game.deck)
      discard_count = length(game.discard_pile)
      hand_count = game.players |> Enum.map(&length(&1.hand)) |> Enum.sum()
      deck_count + discard_count + hand_count
    end
  end
end
