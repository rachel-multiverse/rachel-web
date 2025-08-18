defmodule Rachel.Game.CardTest do
  use ExUnit.Case, async: true
  alias Rachel.Game.Card

  describe "new/2" do
    test "creates a valid card" do
      card = Card.new(:hearts, 7)
      assert card.suit == :hearts
      assert card.rank == 7
    end

    test "creates face cards correctly" do
      jack = Card.new(:spades, 11)
      queen = Card.new(:diamonds, 12)
      king = Card.new(:clubs, 13)
      ace = Card.new(:hearts, 14)

      assert jack.rank == 11
      assert queen.rank == 12
      assert king.rank == 13
      assert ace.rank == 14
    end
  end

  describe "deck/0" do
    test "creates a full 52-card deck" do
      deck = Card.deck()
      assert length(deck) == 52
    end

    test "deck contains all suits and ranks" do
      deck = Card.deck()

      for suit <- [:hearts, :diamonds, :clubs, :spades] do
        for rank <- 2..14 do
          assert Enum.any?(deck, fn card ->
                   card.suit == suit && card.rank == rank
                 end)
        end
      end
    end
  end

  describe "black_jack?/1" do
    test "identifies black jacks correctly" do
      assert Card.black_jack?(Card.new(:spades, 11))
      assert Card.black_jack?(Card.new(:clubs, 11))
      refute Card.black_jack?(Card.new(:hearts, 11))
      refute Card.black_jack?(Card.new(:diamonds, 11))
      refute Card.black_jack?(Card.new(:spades, 12))
    end
  end

  describe "red_jack?/1" do
    test "identifies red jacks correctly" do
      assert Card.red_jack?(Card.new(:hearts, 11))
      assert Card.red_jack?(Card.new(:diamonds, 11))
      refute Card.red_jack?(Card.new(:spades, 11))
      refute Card.red_jack?(Card.new(:clubs, 11))
      refute Card.red_jack?(Card.new(:hearts, 12))
    end
  end

  describe "matches?/2" do
    test "cards match by suit" do
      card1 = Card.new(:hearts, 2)
      card2 = Card.new(:hearts, 10)
      assert Card.matches?(card1, card2)
    end

    test "cards match by rank" do
      card1 = Card.new(:hearts, 7)
      card2 = Card.new(:spades, 7)
      assert Card.matches?(card1, card2)
    end

    test "cards don't match if neither suit nor rank match" do
      card1 = Card.new(:hearts, 2)
      card2 = Card.new(:spades, 10)
      refute Card.matches?(card1, card2)
    end
  end

  describe "display/1" do
    test "displays number cards correctly" do
      assert Card.display(Card.new(:hearts, 2)) == "2♥"
      assert Card.display(Card.new(:spades, 10)) == "10♠"
    end

    test "displays face cards correctly" do
      assert Card.display(Card.new(:clubs, 11)) == "J♣"
      assert Card.display(Card.new(:diamonds, 12)) == "Q♦"
      assert Card.display(Card.new(:hearts, 13)) == "K♥"
      assert Card.display(Card.new(:spades, 14)) == "A♠"
    end
  end

  describe "encode/1 and decode/1" do
    test "encodes and decodes cards correctly" do
      for suit <- [:hearts, :diamonds, :clubs, :spades] do
        for rank <- 2..14 do
          card = Card.new(suit, rank)
          encoded = Card.encode(card)
          {:ok, decoded} = Card.decode(encoded)

          assert decoded.suit == card.suit
          assert decoded.rank == card.rank
        end
      end
    end

    test "specific encoding examples" do
      # 2 of Hearts should be 0x02
      assert Card.encode(Card.new(:hearts, 2)) == 0x02

      # Ace of Spades should be 0xCE (11001110)
      assert Card.encode(Card.new(:spades, 14)) == 0xCE

      # Jack of Clubs should be 0x8B
      assert Card.encode(Card.new(:clubs, 11)) == 0x8B
    end

    test "decode handles invalid bytes" do
      # Rank 0 is invalid
      assert {:error, :invalid_rank} = Card.decode(0x00)
      # Rank 1 is invalid
      assert {:error, :invalid_rank} = Card.decode(0x01)
      # Rank 15 is invalid
      assert {:error, :invalid_rank} = Card.decode(0x0F)
    end
  end
end
