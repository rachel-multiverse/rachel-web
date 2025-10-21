defmodule Rachel.Game.AIStrategyTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{AIStrategy, Card}

  describe "score_play/3" do
    test "easy difficulty returns random score" do
      cards = [Card.new(:hearts, 5)]
      hand = [Card.new(:hearts, 5), Card.new(:spades, 6)]

      score = AIStrategy.score_play(cards, hand, :easy)
      assert score >= 1 and score <= 100
    end

    test "medium difficulty scores attack cards higher" do
      two_cards = [Card.new(:hearts, 2)]
      regular_cards = [Card.new(:hearts, 5)]
      hand = two_cards ++ regular_cards ++ [Card.new(:spades, 6)]

      two_score = AIStrategy.score_play(two_cards, hand, :medium)
      regular_score = AIStrategy.score_play(regular_cards, hand, :medium)

      assert two_score > regular_score
    end

    test "hard difficulty scores Black Jacks highest" do
      black_jack = [Card.new(:spades, 11)]
      two_card = [Card.new(:hearts, 2)]
      regular = [Card.new(:hearts, 5)]
      # Give a larger hand so we're not at the endgame
      hand = black_jack ++ two_card ++ regular ++ [Card.new(:diamonds, 8), Card.new(:clubs, 9)]

      bj_score = AIStrategy.score_play(black_jack, hand, :hard)
      two_score = AIStrategy.score_play(two_card, hand, :hard)
      reg_score = AIStrategy.score_play(regular, hand, :hard)

      assert bj_score > two_score
      assert two_score > reg_score
    end

    test "penalizes Red Jacks in hard mode" do
      red_jack = [Card.new(:hearts, 11)]
      black_jack = [Card.new(:spades, 11)]
      hand = red_jack ++ black_jack

      red_score = AIStrategy.score_play(red_jack, hand, :hard)
      black_score = AIStrategy.score_play(black_jack, hand, :hard)

      # Red Jacks are defensive, should score lower
      assert black_score > red_score
    end

    test "bonus for finishing hand" do
      cards = [Card.new(:hearts, 5)]

      # Hand with only the card being played
      finishing_hand = cards
      finishing_score = AIStrategy.score_play(cards, finishing_hand, :hard)

      # Hand with extra cards
      continuing_hand = cards ++ [Card.new(:spades, 6)]
      continuing_score = AIStrategy.score_play(cards, continuing_hand, :hard)

      assert finishing_score > continuing_score
    end

    test "stacking bonus for medium difficulty" do
      single = [Card.new(:hearts, 7)]
      stacked = [Card.new(:hearts, 7), Card.new(:spades, 7)]
      hand = stacked ++ [Card.new(:clubs, 8), Card.new(:diamonds, 9)]

      single_score = AIStrategy.score_play(single, hand, :medium)
      stacked_score = AIStrategy.score_play(stacked, hand, :medium)

      # More cards in stack = higher score
      assert stacked_score > single_score
    end
  end

  describe "choose_suit/2" do
    test "easy difficulty chooses random suit" do
      hand = [Card.new(:hearts, 5), Card.new(:hearts, 6), Card.new(:hearts, 7)]

      suit = AIStrategy.choose_suit(hand, :easy)
      assert suit in [:hearts, :diamonds, :clubs, :spades]
    end

    test "medium/hard chooses most common suit" do
      hand = [
        Card.new(:hearts, 5),
        Card.new(:hearts, 6),
        Card.new(:hearts, 7),
        Card.new(:spades, 8)
      ]

      assert AIStrategy.choose_suit(hand, :medium) == :hearts
      assert AIStrategy.choose_suit(hand, :hard) == :hearts
    end

    test "handles empty hand" do
      suit = AIStrategy.choose_suit([], :hard)
      assert suit in [:hearts, :diamonds, :clubs, :spades]
    end

    test "handles tie by picking one" do
      hand = [
        Card.new(:hearts, 5),
        Card.new(:spades, 6)
      ]

      suit = AIStrategy.choose_suit(hand, :hard)
      assert suit in [:hearts, :spades]
    end
  end

  describe "choose_counter/3" do
    test "easy chooses single random counter" do
      counters = [Card.new(:hearts, 2), Card.new(:spades, 2)]

      result = AIStrategy.choose_counter(counters, :twos, :easy)
      assert length(result) == 1
      assert hd(result) in counters
    end

    test "medium chooses about half the counters" do
      counters = [
        Card.new(:hearts, 2),
        Card.new(:spades, 2),
        Card.new(:clubs, 2),
        Card.new(:diamonds, 2)
      ]

      result = AIStrategy.choose_counter(counters, :twos, :medium)
      assert length(result) >= 1 and length(result) <= 3
    end

    test "hard stacks all 2s against 2s attack" do
      counters = [Card.new(:hearts, 2), Card.new(:spades, 2)]

      result = AIStrategy.choose_counter(counters, :twos, :hard)
      assert result == counters
    end

    test "hard uses Red Jack efficiently against Black Jacks" do
      counters = [
        # Red Jack
        Card.new(:hearts, 11),
        # Black Jack
        Card.new(:spades, 11)
      ]

      result = AIStrategy.choose_counter(counters, :black_jacks, :hard)
      # Should use only the Red Jack to cancel
      assert result == [Card.new(:hearts, 11)]
    end

    test "hard stacks Black Jacks when no Red Jacks" do
      counters = [
        Card.new(:spades, 11),
        Card.new(:clubs, 11)
      ]

      result = AIStrategy.choose_counter(counters, :black_jacks, :hard)
      assert result == counters
    end
  end
end
