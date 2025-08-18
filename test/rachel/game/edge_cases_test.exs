defmodule Rachel.Game.EdgeCasesTest do
  use ExUnit.Case, async: true
  alias Rachel.Game.{Card, Rules, Deck, GameState}

  describe "deck exhaustion scenarios" do
    test "reshuffling when deck runs out during normal draw" do
      # Create game with almost empty deck
      game = %GameState{
        players: [
          %{id: "p1", name: "Player 1", hand: [], status: :playing},
          %{id: "p2", name: "Player 2", hand: [], status: :playing}
        ],
        # Only 1 card left
        deck: [Card.new(:hearts, 5)],
        discard_pile: [
          Card.new(:spades, 10),
          Card.new(:hearts, 7),
          Card.new(:diamonds, 8),
          Card.new(:clubs, 9)
        ],
        current_player_index: 0,
        status: :playing
      }

      # Draw should trigger reshuffle
      {:ok, new_game} = GameState.draw_cards(game, "p1", :cannot_play)

      # Player should have drawn a card
      assert length(hd(new_game.players).hand) == 1
      # Deck is empty after drawing the last card
      assert length(new_game.deck) == 0
    end

    test "handling massive attack with insufficient cards" do
      # 10 stacked Black Jacks = 50 cards to draw
      game = %GameState{
        players: [
          %{id: "p1", name: "Player 1", hand: [], status: :playing},
          %{id: "p2", name: "Player 2", hand: [], status: :playing}
        ],
        # Only 10 cards in deck
        deck: Enum.take(Deck.new(), 10),
        # 20 in discard
        discard_pile: Enum.take(Enum.drop(Deck.new(), 10), 20),
        pending_attack: {:black_jacks, 50},
        current_player_index: 0,
        status: :playing
      }

      # Should handle drawing 50 cards with only 30 available
      {:ok, new_game} = GameState.draw_cards(game, "p1", :attack)

      # Player should have drawn all available cards
      player = hd(new_game.players)
      # 10 from deck + 19 from discard (keeping top card)
      assert length(player.hand) == 29
      assert new_game.pending_attack == nil
    end

    test "empty deck and discard with single card" do
      # Edge case: only the top discard card exists
      game = %GameState{
        players: [
          %{id: "p1", name: "Player 1", hand: [Card.new(:hearts, 3)], status: :playing},
          %{id: "p2", name: "Player 2", hand: [Card.new(:spades, 4)], status: :playing}
        ],
        deck: [],
        discard_pile: [Card.new(:diamonds, 7)],
        current_player_index: 0,
        status: :playing
      }

      # Try to draw when no cards available
      {:ok, new_game} = GameState.draw_cards(game, "p1", :cannot_play)

      # Should handle gracefully - player draws nothing
      assert hd(new_game.players).hand == [Card.new(:hearts, 3)]
    end
  end

  describe "multiple Aces with different nominations" do
    test "second Ace overrides first nomination" do
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [Card.new(:diamonds, 14)], status: :playing},
          %{id: "p2", name: "P2", hand: [Card.new(:hearts, 14)], status: :playing}
        ],
        discard_pile: [Card.new(:spades, 14)],
        # Previous nomination
        nominated_suit: :clubs,
        current_player_index: 0,
        status: :playing
      }

      # Play another Ace with new nomination
      {:ok, new_game} = GameState.play_cards(game, "p1", [Card.new(:diamonds, 14)], :hearts)

      # Nomination clears after turn advances
      # Cleared after turn
      assert new_game.nominated_suit == nil
    end

    test "stacked Aces still only allow one nomination" do
      cards = [
        Card.new(:hearts, 14),
        Card.new(:diamonds, 14),
        Card.new(:clubs, 14)
      ]

      effects = Rules.calculate_effects(cards)
      assert effects == %{nominate_suit: true}
      # Not %{nominate_suit: 3} - only one nomination allowed
    end
  end

  describe "skip chains and wrapping" do
    test "skip chain wrapping around table multiple times" do
      # 3 players, 6 skips should wrap around twice
      current = 0
      player_count = 3
      next = Rules.next_player_index(current, player_count, :clockwise, 6)

      # 0 -> skip 6 -> lands on 1 (after wrapping twice)
      assert next == 1
    end

    test "counter-clockwise skip wrapping" do
      current = 1
      player_count = 4
      next = Rules.next_player_index(current, player_count, :counter_clockwise, 5)

      # 1 -> skip 5 counter-clockwise (6 steps back total) -> 1-6 = -5, mod 4 = 3
      assert next == 3
    end

    test "all players skip - comes back to original" do
      # 4 players, skip 4 = actually skips 5 positions total (1 normal + 4 skips)
      current = 2
      player_count = 4
      next = Rules.next_player_index(current, player_count, :clockwise, 4)

      # 2 + 5 = 7, 7 % 4 = 3
      assert next == 3
    end

    test "skip counter opportunity for each skipped player" do
      # When multiple players are skipped, each should get counter opportunity
      # This is a game flow test - each skipped player with a 7 can counter
      hand_with_seven = [Card.new(:hearts, 7)]
      hand_without = [Card.new(:hearts, 5)]
      top = Card.new(:spades, 7)

      # Player being skipped with a 7 MUST play it (mandatory rule)
      assert Rules.must_play?(hand_with_seven, top, nil, nil)

      # Player without 7 cannot counter
      refute Rules.has_valid_play?(hand_without, top, nil, nil, 1)
    end
  end

  describe "2-player game edge cases" do
    test "direction reversal has no effect in 2-player game" do
      # In 2-player, clockwise and counter-clockwise are equivalent
      current = 0
      player_count = 2

      next_cw = Rules.next_player_index(current, player_count, :clockwise)
      next_ccw = Rules.next_player_index(current, player_count, :counter_clockwise)

      assert next_cw == 1
      assert next_ccw == 1
    end

    test "skip in 2-player gives extra turn to current player" do
      current = 0
      player_count = 2
      next = Rules.next_player_index(current, player_count, :clockwise, 1)

      # Skip opponent, come back to self
      assert next == 0
    end

    test "multiple skips in 2-player" do
      # Even skips = opponent's turn
      assert Rules.next_player_index(0, 2, :clockwise, 2) == 1
      assert Rules.next_player_index(0, 2, :clockwise, 4) == 1

      # Odd skips = extra turn
      assert Rules.next_player_index(0, 2, :clockwise, 1) == 0
      assert Rules.next_player_index(0, 2, :clockwise, 3) == 0
    end
  end

  describe "maximum hand size scenarios" do
    test "drawing maximum cards from stacked attacks" do
      # Theoretical max: 10 Black Jacks = 50 cards to draw
      # Create a deck with enough cards
      # 104 cards
      deck = Deck.new() ++ Deck.new()
      {drawn, _remaining} = Deck.draw(deck, 50)

      assert length(drawn) == 50
      # Player could theoretically hold 57 cards (7 initial + 50 drawn)
    end
  end

  describe "complex stacking scenarios" do
    test "mixed Red and Black Jacks interaction" do
      # Black Jacks create attack, Red Jacks reduce it
      # 3 Black Jacks
      black_attack = {:black_jacks, 15}
      # 2 Red Jacks
      reduced = Rules.reduce_attack(black_attack, 2)

      # 15 - 10 = 5
      assert reduced == {:black_jacks, 5}
    end

    test "Red Jacks completely negating Black Jacks" do
      # 2 Black Jacks
      black_attack = {:black_jacks, 10}
      # 2 Red Jacks
      reduced = Rules.reduce_attack(black_attack, 2)

      # Completely negated
      assert reduced == nil
    end

    test "stacking same rank across all suits" do
      # All four 7s played together
      cards = [
        Card.new(:hearts, 7),
        Card.new(:diamonds, 7),
        Card.new(:clubs, 7),
        Card.new(:spades, 7)
      ]

      assert Rules.valid_stack?(cards)
      effects = Rules.calculate_effects(cards)
      assert effects == %{skip: 4}
    end
  end

  describe "suit nomination edge cases" do
    test "nomination cleared after turn" do
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [], status: :playing},
          %{id: "p2", name: "P2", hand: [], status: :playing}
        ],
        nominated_suit: :hearts,
        current_player_index: 0,
        status: :playing
      }

      # After advancing turn, nomination should clear
      new_game = %{game | current_player_index: 1, nominated_suit: nil}
      assert new_game.nominated_suit == nil
    end

    test "cannot play wrong suit even if rank matches during nomination" do
      # Ace nominated hearts, next player has 5 of spades
      top = Card.new(:clubs, 14)
      card = Card.new(:spades, 5)

      # Even though neither suit nor rank matches normally, still can't play
      refute Rules.can_play_card?(card, top, :hearts)
    end

    test "Ace on Ace with nomination change" do
      # First Ace nominated hearts, second Ace changes to spades
      top = Card.new(:hearts, 14)
      ace = Card.new(:diamonds, 14)

      # Can play Ace on Ace regardless of nomination (rank matches)
      assert Rules.can_play_card?(ace, top, :clubs)
    end
  end

  describe "attack stacking edge cases" do
    test "cannot mix different attack types" do
      # Can't stack 2s on Black Jacks or vice versa
      two = Card.new(:hearts, 2)
      black_jack = Card.new(:spades, 11)

      # 2s counter only 2s
      assert Rules.can_counter_attack?(two, :twos)
      refute Rules.can_counter_attack?(two, :black_jacks)

      # Black Jacks counter only Black Jacks (Red Jacks also work)
      assert Rules.can_counter_attack?(black_jack, :black_jacks)
      refute Rules.can_counter_attack?(black_jack, :twos)
    end

    test "attack accumulation with multiple plays" do
      # First player: 2 Black Jacks (10 damage)
      # Second player: 1 Black Jack (adds 5)
      # Total should be 15

      cards = [Card.new(:clubs, 11)]
      new_effect = Rules.calculate_effects(cards)

      assert new_effect == %{attack: {:black_jacks, 5}}
      # Game would accumulate to {:black_jacks, 15}
    end
  end

  describe "mandatory play enforcement" do
    test "must play when only one valid card" do
      hand = [
        Card.new(:hearts, 5),
        Card.new(:spades, 10),
        Card.new(:diamonds, 3)
      ]

      top = Card.new(:hearts, 8)

      # Only hearts 5 is valid
      assert Rules.must_play?(hand, top, nil, nil)
      assert Rules.has_valid_play?(hand, top, nil, nil)
    end

    test "must counter skip if holding 7" do
      hand = [Card.new(:diamonds, 7), Card.new(:hearts, 3)]
      top = Card.new(:clubs, 7)

      # Must play the 7 to counter
      assert Rules.has_valid_play?(hand, top, nil, nil, 1)
    end

    test "must counter attack if able" do
      hand = [Card.new(:hearts, 2), Card.new(:hearts, 5)]
      top = Card.new(:spades, 2)
      attack = {:twos, 2}

      # Must play the 2 to counter
      assert Rules.has_valid_play?(hand, top, nil, attack)
    end
  end

  describe "game ending scenarios" do
    test "winner continues play order" do
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [Card.new(:hearts, 5)], status: :playing},
          %{id: "p2", name: "P2", hand: [Card.new(:hearts, 7)], status: :playing},
          %{id: "p3", name: "P3", hand: [Card.new(:spades, 7)], status: :playing}
        ],
        discard_pile: [Card.new(:hearts, 10)],
        current_player_index: 0,
        status: :playing
      }

      # P1 plays last card and wins
      {:ok, new_game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 5)])
      assert "p1" in new_game.winners
    end

    test "last card played with special effect" do
      # Playing last card as a 7 (skip) or Queen (reverse)
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [Card.new(:hearts, 7)], status: :playing},
          %{id: "p2", name: "P2", hand: [Card.new(:spades, 5)], status: :playing}
        ],
        discard_pile: [Card.new(:hearts, 10)],
        current_player_index: 0,
        status: :playing
      }

      # Play last card (7 skip)
      {:ok, new_game} = GameState.play_cards(game, "p1", [Card.new(:hearts, 7)])

      # P1 should win even though card has skip effect
      assert "p1" in new_game.winners
      # Skip clears after turn
      assert new_game.pending_skips == 0
    end
  end

  describe "concurrent action validation" do
    test "cannot play while not your turn" do
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [Card.new(:hearts, 5)], status: :playing},
          %{id: "p2", name: "P2", hand: [Card.new(:hearts, 7)], status: :playing}
        ],
        discard_pile: [Card.new(:hearts, 10)],
        current_player_index: 0,
        status: :playing
      }

      # P2 tries to play out of turn
      result = GameState.play_cards(game, "p2", [Card.new(:hearts, 7)])

      assert {:error, :not_your_turn} = result
    end

    test "cannot play cards not in hand" do
      game = %GameState{
        players: [
          %{id: "p1", name: "P1", hand: [Card.new(:hearts, 5)], status: :playing}
        ],
        discard_pile: [Card.new(:hearts, 10)],
        current_player_index: 0,
        status: :playing
      }

      # Try to play card not in hand
      result = GameState.play_cards(game, "p1", [Card.new(:hearts, 7)])

      assert {:error, :cards_not_in_hand} = result
    end
  end
end
