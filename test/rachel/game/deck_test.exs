defmodule Rachel.Game.DeckTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.Card
  alias Rachel.Game.Deck

  describe "new/1" do
    test "creates a standard 52-card deck" do
      deck = Deck.new()

      assert length(deck) == 52
      assert is_list(deck)
      assert Enum.all?(deck, &is_struct(&1, Card))
    end

    test "creates multiple decks when specified" do
      deck = Deck.new(2)

      assert length(deck) == 104
      assert is_list(deck)
    end

    test "shuffles the deck" do
      # Create two decks and verify they're different (highly unlikely to be same if shuffled)
      deck1 = Deck.new()
      deck2 = Deck.new()

      # At least one difference in the first 10 cards (probabilistically certain)
      first_10_deck1 = Enum.take(deck1, 10)
      first_10_deck2 = Enum.take(deck2, 10)

      assert first_10_deck1 != first_10_deck2
    end

    test "creates valid cards with proper suits and ranks" do
      deck = Deck.new()

      # Count cards by suit
      suits_count =
        deck
        |> Enum.group_by(& &1.suit)
        |> Enum.map(fn {suit, cards} -> {suit, length(cards)} end)
        |> Map.new()

      assert suits_count[:hearts] == 13
      assert suits_count[:diamonds] == 13
      assert suits_count[:clubs] == 13
      assert suits_count[:spades] == 13
    end

    test "creates three decks correctly" do
      deck = Deck.new(3)

      assert length(deck) == 156
    end
  end

  describe "deal/2" do
    test "deals 7 cards to each player for 2 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 2)

      assert length(hands) == 2
      assert Enum.all?(hands, &(length(&1) == 7))
      assert length(remaining) == 52 - 14
    end

    test "deals 7 cards to each player for 3 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 3)

      assert length(hands) == 3
      assert Enum.all?(hands, &(length(&1) == 7))
      assert length(remaining) == 52 - 21
    end

    test "deals 7 cards to each player for 4 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 4)

      assert length(hands) == 4
      assert Enum.all?(hands, &(length(&1) == 7))
      assert length(remaining) == 52 - 28
    end

    test "deals 7 cards to each player for 5 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 5)

      assert length(hands) == 5
      assert Enum.all?(hands, &(length(&1) == 7))
      assert length(remaining) == 52 - 35
    end

    test "deals 6 cards to each player for 6 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 6)

      assert length(hands) == 6
      assert Enum.all?(hands, &(length(&1) == 6))
      assert length(remaining) == 52 - 36
    end

    test "deals 6 cards to each player for 7 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 7)

      assert length(hands) == 7
      assert Enum.all?(hands, &(length(&1) == 6))
      assert length(remaining) == 52 - 42
    end

    test "deals 5 cards to each player for 8 players" do
      deck = Deck.new()

      {hands, remaining} = Deck.deal(deck, 8)

      assert length(hands) == 8
      assert Enum.all?(hands, &(length(&1) == 5))
      assert length(remaining) == 52 - 40
    end

    test "raises error for invalid player count (1 player)" do
      deck = Deck.new()

      assert_raise RuntimeError, ~r/Invalid player count/, fn ->
        Deck.deal(deck, 1)
      end
    end

    test "raises error for invalid player count (9 players)" do
      deck = Deck.new()

      assert_raise RuntimeError, ~r/Invalid player count/, fn ->
        Deck.deal(deck, 9)
      end
    end

    test "raises error when deck doesn't have enough cards" do
      # Create a small deck with only 10 cards
      small_deck = Enum.take(Deck.new(), 10)

      # Try to deal to 2 players (needs 14 cards)
      assert_raise RuntimeError, ~r/Not enough cards/, fn ->
        Deck.deal(small_deck, 2)
      end
    end

    test "each player gets unique cards (no duplicates across hands)" do
      deck = Deck.new()

      {hands, _remaining} = Deck.deal(deck, 4)

      all_dealt_cards = List.flatten(hands)
      unique_cards = Enum.uniq(all_dealt_cards)

      assert length(all_dealt_cards) == length(unique_cards)
    end

    test "hands are properly distributed" do
      deck = Deck.new()

      {hands, _remaining} = Deck.deal(deck, 3)

      # Each hand should be a list of Card structs
      assert Enum.all?(hands, fn hand ->
               is_list(hand) and Enum.all?(hand, &is_struct(&1, Card))
             end)
    end
  end

  describe "draw/2" do
    test "draws specified number of cards" do
      deck = Deck.new()

      {drawn, remaining} = Deck.draw(deck, 5)

      assert length(drawn) == 5
      assert length(remaining) == 47
      assert Enum.all?(drawn, &is_struct(&1, Card))
    end

    test "draws all cards when count equals deck size" do
      deck = Deck.new()

      {drawn, remaining} = Deck.draw(deck, 52)

      assert length(drawn) == 52
      assert remaining == []
    end

    test "draws from top of deck in order" do
      deck = Deck.new()
      first_three = Enum.take(deck, 3)

      {drawn, _remaining} = Deck.draw(deck, 3)

      assert drawn == first_three
    end

    test "draws zero cards when count is 0" do
      deck = Deck.new()

      {drawn, remaining} = Deck.draw(deck, 0)

      assert drawn == []
      assert length(remaining) == 52
    end

    test "draws zero cards when count is negative" do
      deck = Deck.new()

      {drawn, remaining} = Deck.draw(deck, -5)

      assert drawn == []
      assert length(remaining) == 52
    end

    test "handles drawing more cards than available" do
      small_deck = Enum.take(Deck.new(), 5)

      {drawn, remaining} = Deck.draw(small_deck, 10)

      # Enum.split will give us all 5 cards
      assert length(drawn) == 5
      assert remaining == []
    end

    test "works with empty deck" do
      {drawn, remaining} = Deck.draw([], 5)

      assert drawn == []
      assert remaining == []
    end

    test "drawn cards are removed from remaining deck" do
      deck = Deck.new()
      {drawn, remaining} = Deck.draw(deck, 3)

      # Verify drawn cards are not in remaining
      assert Enum.all?(drawn, fn card ->
               not Enum.member?(remaining, card)
             end)
    end
  end

  describe "draw_one/1" do
    test "draws the first card from deck" do
      deck = Deck.new()
      expected_card = hd(deck)

      {card, remaining} = Deck.draw_one(deck)

      assert card == expected_card
      assert length(remaining) == 51
      assert card not in remaining
    end

    test "returns nil for empty deck" do
      {card, remaining} = Deck.draw_one([])

      assert card == nil
      assert remaining == []
    end

    test "successive draws get different cards" do
      deck = Deck.new()

      {card1, deck2} = Deck.draw_one(deck)
      {card2, deck3} = Deck.draw_one(deck2)
      {card3, _deck4} = Deck.draw_one(deck3)

      assert card1 != card2
      assert card2 != card3
      assert card1 != card3
    end

    test "draws all cards from small deck" do
      small_deck = [Card.new(:hearts, 5), Card.new(:spades, 6), Card.new(:clubs, 7)]

      {card1, deck1} = Deck.draw_one(small_deck)
      {card2, deck2} = Deck.draw_one(deck1)
      {card3, deck3} = Deck.draw_one(deck2)
      {card4, _deck4} = Deck.draw_one(deck3)

      assert card1 == Card.new(:hearts, 5)
      assert card2 == Card.new(:spades, 6)
      assert card3 == Card.new(:clubs, 7)
      assert card4 == nil
    end

    test "works with single card deck" do
      deck = [Card.new(:hearts, 5)]

      {card, remaining} = Deck.draw_one(deck)

      assert card == Card.new(:hearts, 5)
      assert remaining == []
    end
  end

  describe "reshuffle_discard/1" do
    test "keeps top card and reshuffles rest" do
      discard = [
        Card.new(:hearts, 5),
        Card.new(:spades, 6),
        Card.new(:clubs, 7),
        Card.new(:diamonds, 8)
      ]

      {top_card, new_deck} = Deck.reshuffle_discard(discard)

      assert top_card == Card.new(:hearts, 5)
      assert length(new_deck) == 3

      # Verify all cards from rest are in new deck
      rest_cards = [Card.new(:spades, 6), Card.new(:clubs, 7), Card.new(:diamonds, 8)]
      assert Enum.sort(new_deck) == Enum.sort(rest_cards)
    end

    test "shuffles the cards (probabilistic test)" do
      discard = [
        Card.new(:hearts, 5),
        Card.new(:spades, 6),
        Card.new(:clubs, 7),
        Card.new(:diamonds, 8),
        Card.new(:hearts, 9),
        Card.new(:spades, 10),
        Card.new(:clubs, 11),
        Card.new(:diamonds, 12)
      ]

      {_top1, deck1} = Deck.reshuffle_discard(discard)
      {_top2, deck2} = Deck.reshuffle_discard(discard)

      # Two reshuffles should (almost certainly) produce different orders
      assert deck1 != deck2
    end

    test "returns empty deck for single card discard" do
      discard = [Card.new(:hearts, 5)]

      {top_card, new_deck} = Deck.reshuffle_discard(discard)

      assert top_card == Card.new(:hearts, 5)
      assert new_deck == []
    end

    test "returns empty deck for two card discard" do
      discard = [Card.new(:hearts, 5), Card.new(:spades, 6)]

      {top_card, new_deck} = Deck.reshuffle_discard(discard)

      assert top_card == Card.new(:hearts, 5)
      assert length(new_deck) == 1
      assert new_deck == [Card.new(:spades, 6)]
    end

    test "handles empty discard pile" do
      {top_card, new_deck} = Deck.reshuffle_discard([])

      assert top_card == nil
      assert new_deck == []
    end

    test "keeps exact top card even with duplicates" do
      discard = [
        Card.new(:hearts, 5),
        Card.new(:hearts, 5),
        Card.new(:spades, 6)
      ]

      {top_card, new_deck} = Deck.reshuffle_discard(discard)

      assert top_card == Card.new(:hearts, 5)
      assert length(new_deck) == 2
    end

    test "large discard pile reshuffle" do
      # Create a large discard pile
      large_discard = Enum.take(Deck.new(), 40)
      top = hd(large_discard)

      {top_card, new_deck} = Deck.reshuffle_discard(large_discard)

      assert top_card == top
      assert length(new_deck) == 39
    end
  end

  describe "integration scenarios" do
    test "full game deck lifecycle" do
      # 1. Create deck
      deck = Deck.new()
      assert length(deck) == 52

      # 2. Deal to players
      {hands, remaining} = Deck.deal(deck, 4)
      assert length(hands) == 4
      assert Enum.all?(hands, &(length(&1) == 7))
      assert length(remaining) == 24

      # 3. Draw initial discard
      {discard, remaining} = Deck.draw(remaining, 1)
      assert length(discard) == 1
      assert length(remaining) == 23

      # 4. Draw some cards
      {drawn, remaining} = Deck.draw(remaining, 5)
      assert length(drawn) == 5
      assert length(remaining) == 18

      # 5. Build up discard pile
      discard_pile = discard ++ drawn

      # 6. Reshuffle when deck low
      {top, new_deck} = Deck.reshuffle_discard(discard_pile)
      assert top == hd(discard_pile)
      assert length(new_deck) == 5
    end

    test "multiple deck game" do
      # Create 2-deck game for more players
      deck = Deck.new(2)
      assert length(deck) == 104

      {hands, remaining} = Deck.deal(deck, 8)
      assert length(hands) == 8
      assert Enum.all?(hands, &(length(&1) == 5))
      assert length(remaining) == 64
    end
  end
end
