defmodule Rachel.Game.DeckOperationsTest do
  use ExUnit.Case, async: true
  
  alias Rachel.Game.{Card, DeckOperations}

  describe "draw_cards/3" do
    test "draws cards when deck has enough" do
      deck = [Card.new(:hearts, 5), Card.new(:spades, 6), Card.new(:clubs, 7)]
      discard = [Card.new(:diamonds, 8)]
      
      {:ok, {drawn, new_deck, new_discard}} = DeckOperations.draw_cards(deck, discard, 2)
      
      assert length(drawn) == 2
      assert drawn == [Card.new(:hearts, 5), Card.new(:spades, 6)]
      assert new_deck == [Card.new(:clubs, 7)]
      assert new_discard == discard
    end

    test "reshuffles when deck doesn't have enough" do
      deck = [Card.new(:hearts, 5)]
      discard = [
        Card.new(:diamonds, 8),  # Top card (stays)
        Card.new(:clubs, 9),
        Card.new(:spades, 10)
      ]
      
      {:ok, {drawn, new_deck, new_discard}} = DeckOperations.draw_cards(deck, discard, 3)
      
      assert length(drawn) == 3
      assert Card.new(:hearts, 5) in drawn
      # The other cards come from reshuffled discard
      assert length(new_deck) <= 1
      assert new_discard == [Card.new(:diamonds, 8)]
    end

    test "returns empty when only one discard card" do
      deck = []
      discard = [Card.new(:diamonds, 8)]
      
      {:ok, {drawn, new_deck, new_discard}} = DeckOperations.draw_cards(deck, discard, 1)
      
      assert drawn == []
      assert new_deck == []
      assert new_discard == discard
    end

    test "handles drawing zero cards" do
      deck = [Card.new(:hearts, 5)]
      discard = [Card.new(:diamonds, 8)]
      
      {:ok, {drawn, new_deck, new_discard}} = DeckOperations.draw_cards(deck, discard, 0)
      
      assert drawn == []
      assert new_deck == []
      assert new_discard == []
    end
  end

  describe "add_to_hand/3" do
    test "adds cards to player's hand" do
      players = [
        %{id: "p1", hand: [Card.new(:hearts, 5)]},
        %{id: "p2", hand: []}
      ]
      
      new_cards = [Card.new(:spades, 6), Card.new(:clubs, 7)]
      result = DeckOperations.add_to_hand(players, 0, new_cards)
      
      assert Enum.at(result, 0).hand == [
        Card.new(:hearts, 5),
        Card.new(:spades, 6),
        Card.new(:clubs, 7)
      ]
      assert Enum.at(result, 1).hand == []
    end
  end

  describe "remove_from_hand/3" do
    test "removes specific cards from hand" do
      players = [
        %{id: "p1", hand: [
          Card.new(:hearts, 5),
          Card.new(:spades, 5),
          Card.new(:clubs, 7)
        ]}
      ]
      
      cards_to_remove = [Card.new(:hearts, 5), Card.new(:clubs, 7)]
      result = DeckOperations.remove_from_hand(players, 0, cards_to_remove)
      
      assert Enum.at(result, 0).hand == [Card.new(:spades, 5)]
    end

    test "handles duplicate cards correctly" do
      players = [
        %{id: "p1", hand: [
          Card.new(:hearts, 5),
          Card.new(:hearts, 5),  # Duplicate
          Card.new(:clubs, 7)
        ]}
      ]
      
      # Remove only one of the hearts 5
      cards_to_remove = [Card.new(:hearts, 5)]
      result = DeckOperations.remove_from_hand(players, 0, cards_to_remove)
      
      # Should still have one hearts 5
      assert Enum.at(result, 0).hand == [
        Card.new(:hearts, 5),
        Card.new(:clubs, 7)
      ]
    end

    test "handles cards not in hand gracefully" do
      players = [
        %{id: "p1", hand: [Card.new(:hearts, 5)]}
      ]
      
      # Try to remove a card that's not there
      cards_to_remove = [Card.new(:spades, 10)]
      result = DeckOperations.remove_from_hand(players, 0, cards_to_remove)
      
      # Hand should be unchanged
      assert Enum.at(result, 0).hand == [Card.new(:hearts, 5)]
    end
  end

  describe "validate_card_count/4" do
    test "validates correct card count" do
      players = [
        %{hand: [Card.new(:hearts, 5), Card.new(:spades, 6)]},
        %{hand: [Card.new(:clubs, 7)]}
      ]
      deck = [Card.new(:diamonds, 8)]
      discard = [Card.new(:hearts, 9)]
      
      assert :ok = DeckOperations.validate_card_count(players, deck, discard, 5)
    end

    test "detects incorrect card count" do
      players = [
        %{hand: [Card.new(:hearts, 5)]}
      ]
      deck = [Card.new(:diamonds, 8)]
      discard = [Card.new(:hearts, 9)]
      
      assert {:error, {:card_count, 3}} = DeckOperations.validate_card_count(players, deck, discard, 5)
    end
  end
end