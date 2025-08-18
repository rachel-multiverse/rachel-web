defmodule Rachel.Game.RulesTest do
  use ExUnit.Case, async: true
  alias Rachel.Game.{Card, Rules}

  describe "can_play_card?/3 - basic matching" do
    test "can play card with matching suit" do
      card = Card.new(:hearts, 5)
      top = Card.new(:hearts, 10)
      assert Rules.can_play_card?(card, top)
    end

    test "can play card with matching rank" do
      card = Card.new(:spades, 7)
      top = Card.new(:hearts, 7)
      assert Rules.can_play_card?(card, top)
    end

    test "cannot play card with no match" do
      card = Card.new(:spades, 5)
      top = Card.new(:hearts, 10)
      refute Rules.can_play_card?(card, top)
    end

    test "Aces must match suit or rank like any other card" do
      ace_hearts = Card.new(:hearts, 14)
      ace_spades = Card.new(:spades, 14)

      # Can play Ace if suits match
      assert Rules.can_play_card?(ace_hearts, Card.new(:hearts, 5))

      # Can play Ace if rank matches (another Ace)
      assert Rules.can_play_card?(ace_spades, Card.new(:hearts, 14))

      # Cannot play Ace if neither matches
      refute Rules.can_play_card?(ace_spades, Card.new(:hearts, 5))
    end
  end

  describe "can_play_card?/3 - responding to Ace suit nomination" do
    test "must match nominated suit when active" do
      card_hearts = Card.new(:hearts, 5)
      card_spades = Card.new(:spades, 5)
      # Ace was played
      top = Card.new(:clubs, 14)

      # Must play hearts when hearts was nominated
      assert Rules.can_play_card?(card_hearts, top, :hearts)

      # Cannot play other suits (even if rank matches!)
      refute Rules.can_play_card?(card_spades, top, :hearts)
    end

    test "can play an Ace to respond to nomination (matches rank)" do
      ace_diamonds = Card.new(:diamonds, 14)
      # Previous Ace
      top = Card.new(:clubs, 14)

      # Can play another Ace because rank matches
      assert Rules.can_play_card?(ace_diamonds, top, :hearts)
    end

    test "cannot play non-matching card even with nomination" do
      card = Card.new(:spades, 5)
      top = Card.new(:clubs, 14)

      # Cannot play spades when hearts nominated
      refute Rules.can_play_card?(card, top, :hearts)
    end
  end

  describe "can_counter_attack?/2" do
    test "2s can only counter 2s" do
      two = Card.new(:hearts, 2)
      assert Rules.can_counter_attack?(two, :twos)
      refute Rules.can_counter_attack?(two, :black_jacks)
    end

    test "Black Jacks can counter Black Jack attacks" do
      black_jack = Card.new(:spades, 11)
      assert Rules.can_counter_attack?(black_jack, :black_jacks)
      refute Rules.can_counter_attack?(black_jack, :twos)
    end

    test "Red Jacks can counter Black Jack attacks" do
      red_jack = Card.new(:hearts, 11)
      assert Rules.can_counter_attack?(red_jack, :black_jacks)
      refute Rules.can_counter_attack?(red_jack, :twos)
    end

    test "multiple Red Jacks can be played together" do
      red_jacks = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      # Both can counter Black Jack attacks
      assert Enum.all?(red_jacks, &Rules.can_counter_attack?(&1, :black_jacks))
    end
  end

  describe "can_counter_skip?/1" do
    test "7s can counter skips" do
      seven = Card.new(:diamonds, 7)
      assert Rules.can_counter_skip?(seven)
    end

    test "non-7s cannot counter skips" do
      refute Rules.can_counter_skip?(Card.new(:hearts, 2))
      refute Rules.can_counter_skip?(Card.new(:hearts, 11))
      refute Rules.can_counter_skip?(Card.new(:hearts, 14))
    end
  end

  describe "valid_stack?/1" do
    test "single card is valid" do
      assert Rules.valid_stack?([Card.new(:hearts, 5)])
    end

    test "multiple cards of same rank are valid" do
      cards = [
        Card.new(:hearts, 7),
        Card.new(:diamonds, 7),
        Card.new(:clubs, 7)
      ]

      assert Rules.valid_stack?(cards)
    end

    test "cards of different ranks are invalid" do
      cards = [
        Card.new(:hearts, 7),
        Card.new(:hearts, 8)
      ]

      refute Rules.valid_stack?(cards)
    end

    test "empty list is invalid" do
      refute Rules.valid_stack?([])
    end
  end

  describe "calculate_effects/1" do
    test "2s create draw attack" do
      cards = [Card.new(:hearts, 2), Card.new(:spades, 2)]
      assert Rules.calculate_effects(cards) == %{attack: {:twos, 4}}
    end

    test "7s create skip effect" do
      cards = [Card.new(:hearts, 7), Card.new(:diamonds, 7), Card.new(:clubs, 7)]
      assert Rules.calculate_effects(cards) == %{skip: 3}
    end

    test "odd number of Queens reverses direction" do
      # One Queen reverses
      assert Rules.calculate_effects([Card.new(:hearts, 12)]) == %{reverse: true}

      # Three Queens reverse
      cards = [
        Card.new(:hearts, 12),
        Card.new(:diamonds, 12),
        Card.new(:clubs, 12)
      ]

      assert Rules.calculate_effects(cards) == %{reverse: true}
    end

    test "even number of Queens don't reverse" do
      # Two Queens don't reverse
      cards = [Card.new(:hearts, 12), Card.new(:spades, 12)]
      assert Rules.calculate_effects(cards) == %{}

      # Four Queens don't reverse
      cards = [
        Card.new(:hearts, 12),
        Card.new(:diamonds, 12),
        Card.new(:clubs, 12),
        Card.new(:spades, 12)
      ]

      assert Rules.calculate_effects(cards) == %{}
    end

    test "Black Jacks create draw five attack" do
      cards = [Card.new(:spades, 11), Card.new(:clubs, 11)]
      assert Rules.calculate_effects(cards) == %{attack: {:black_jacks, 10}}
    end

    test "Aces trigger suit nomination" do
      cards = [Card.new(:hearts, 14)]
      assert Rules.calculate_effects(cards) == %{nominate_suit: true}
    end

    test "multiple Aces still only trigger one nomination" do
      cards = [
        Card.new(:hearts, 14),
        Card.new(:diamonds, 14),
        Card.new(:clubs, 14)
      ]

      assert Rules.calculate_effects(cards) == %{nominate_suit: true}
    end

    test "regular cards have no effects" do
      cards = [Card.new(:hearts, 5), Card.new(:diamonds, 5)]
      assert Rules.calculate_effects(cards) == %{}
    end
  end

  describe "cards_per_player/1" do
    test "correct card distribution" do
      assert Rules.cards_per_player(2) == 7
      assert Rules.cards_per_player(3) == 7
      assert Rules.cards_per_player(4) == 7
      assert Rules.cards_per_player(5) == 7
      assert Rules.cards_per_player(6) == 6
      assert Rules.cards_per_player(7) == 6
      assert Rules.cards_per_player(8) == 5
      assert Rules.cards_per_player(1) == {:error, :invalid_player_count}
      assert Rules.cards_per_player(9) == {:error, :invalid_player_count}
    end
  end

  describe "has_valid_play?/5" do
    test "has valid play with matching suit" do
      hand = [Card.new(:hearts, 5), Card.new(:spades, 10)]
      top = Card.new(:hearts, 7)
      assert Rules.has_valid_play?(hand, top, nil, nil)
    end

    test "has valid play with matching rank" do
      hand = [Card.new(:hearts, 5), Card.new(:spades, 7)]
      top = Card.new(:diamonds, 7)
      assert Rules.has_valid_play?(hand, top, nil, nil)
    end

    test "no valid play when no matches" do
      hand = [Card.new(:hearts, 5), Card.new(:hearts, 6)]
      top = Card.new(:spades, 10)
      refute Rules.has_valid_play?(hand, top, nil, nil)
    end

    test "can only play counter when facing attack" do
      hand = [
        # Can counter
        Card.new(:hearts, 2),
        # Cannot counter
        Card.new(:hearts, 5)
      ]

      top = Card.new(:spades, 2)

      # When facing twos attack, only 2s are valid
      assert Rules.has_valid_play?(hand, top, nil, {:twos, 2})

      # But the 5 would be valid without attack
      assert Rules.has_valid_play?([Card.new(:hearts, 5)], Card.new(:hearts, 10), nil, nil)
    end

    test "must match nominated suit or play Ace" do
      hand = [
        # Matches nomination
        Card.new(:hearts, 5),
        # Doesn't match
        Card.new(:spades, 5),
        # Ace - matches rank
        Card.new(:diamonds, 14)
      ]

      # Ace was played
      top = Card.new(:clubs, 14)

      # With hearts nominated, only hearts card and Ace are valid
      assert Rules.has_valid_play?(hand, top, :hearts, nil)

      # Without the hearts card, still valid because of Ace
      assert Rules.has_valid_play?(
               [Card.new(:spades, 5), Card.new(:diamonds, 14)],
               top,
               :hearts,
               nil
             )

      # Without hearts or Ace, no valid play
      refute Rules.has_valid_play?([Card.new(:spades, 5), Card.new(:clubs, 7)], top, :hearts, nil)
    end

    test "when facing skips, can only play 7s" do
      hand = [
        # Can counter skip
        Card.new(:hearts, 7),
        # Cannot counter skip
        Card.new(:hearts, 5)
      ]

      top = Card.new(:spades, 7)

      # When facing skip, only 7s are valid
      assert Rules.has_valid_play?(hand, top, nil, nil, 1)

      # Without a 7, no valid play when facing skip
      refute Rules.has_valid_play?([Card.new(:hearts, 5)], top, nil, nil, 1)
    end

    test "must play 7 if you have it when facing skip (mandatory play)" do
      hand = [Card.new(:hearts, 7)]
      top = Card.new(:spades, 7)

      # If you have a 7 when facing skip, you MUST play it
      assert Rules.must_play?(hand, top, nil, nil)
    end
  end

  describe "reduce_attack/2" do
    test "Red Jacks reduce Black Jack attacks" do
      assert Rules.reduce_attack({:black_jacks, 10}, 1) == {:black_jacks, 5}
      assert Rules.reduce_attack({:black_jacks, 10}, 2) == nil
      assert Rules.reduce_attack({:black_jacks, 5}, 1) == nil
    end

    test "Red Jacks don't affect other attacks" do
      assert Rules.reduce_attack({:twos, 4}, 1) == {:twos, 4}
    end
  end

  describe "next_player_index/4" do
    test "clockwise movement" do
      # 4 players, current player 1, clockwise
      assert Rules.next_player_index(1, 4, :clockwise) == 2
      # Wrap around
      assert Rules.next_player_index(3, 4, :clockwise) == 0
    end

    test "counter-clockwise movement" do
      assert Rules.next_player_index(1, 4, :counter_clockwise) == 0
      # Wrap around
      assert Rules.next_player_index(0, 4, :counter_clockwise) == 3
    end

    test "skipping players" do
      # Skip 2 players clockwise from player 0
      assert Rules.next_player_index(0, 4, :clockwise, 2) == 3

      # Skip 1 player counter-clockwise from player 1
      assert Rules.next_player_index(1, 4, :counter_clockwise, 1) == 3
    end
  end

  describe "must_play?/4 - mandatory play rule" do
    test "must play if has valid card" do
      hand = [Card.new(:hearts, 5)]
      top = Card.new(:hearts, 10)
      assert Rules.must_play?(hand, top, nil, nil)
    end

    test "cannot be forced to play if no valid cards" do
      hand = [Card.new(:spades, 5)]
      top = Card.new(:hearts, 10)
      refute Rules.must_play?(hand, top, nil, nil)
    end
  end
end
