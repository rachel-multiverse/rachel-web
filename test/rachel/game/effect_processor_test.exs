defmodule Rachel.Game.EffectProcessorTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{Card, EffectProcessor}

  setup do
    game = %{
      pending_attack: nil,
      pending_skips: 0,
      nominated_suit: nil,
      direction: :clockwise
    }

    {:ok, game: game}
  end

  describe "apply_effects/3" do
    test "applies 2s attack effect", %{game: game} do
      cards = [Card.new(:hearts, 2), Card.new(:spades, 2)]
      result = EffectProcessor.apply_effects(game, cards)
      # Two 2s = draw 4
      assert result.pending_attack == {:twos, 4}
    end

    test "applies 7s skip effect", %{game: game} do
      cards = [Card.new(:hearts, 7), Card.new(:diamonds, 7)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result.pending_skips == 2
    end

    test "applies Queen reverse effect", %{game: game} do
      cards = [Card.new(:hearts, 12)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result.direction == :counter_clockwise
    end

    test "double Queens cancel reverse", %{game: game} do
      cards = [Card.new(:hearts, 12), Card.new(:spades, 12)]
      result = EffectProcessor.apply_effects(game, cards)
      # Even number of Queens = no direction change
      assert result.direction == :clockwise
    end

    test "triple Queens reverse direction", %{game: game} do
      cards = [Card.new(:hearts, 12), Card.new(:spades, 12), Card.new(:clubs, 12)]
      result = EffectProcessor.apply_effects(game, cards)
      # Odd number of Queens = direction change
      assert result.direction == :counter_clockwise
    end

    test "applies Ace suit nomination", %{game: game} do
      cards = [Card.new(:hearts, 14)]
      result = EffectProcessor.apply_effects(game, cards, :diamonds)
      assert result.nominated_suit == :diamonds
    end

    test "Ace without nomination doesn't set suit", %{game: game} do
      cards = [Card.new(:hearts, 14)]
      result = EffectProcessor.apply_effects(game, cards, nil)
      assert result.nominated_suit == nil
    end

    test "applies Black Jack attack", %{game: game} do
      cards = [Card.new(:spades, 11), Card.new(:clubs, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # Two Black Jacks = draw 10
      assert result.pending_attack == {:black_jacks, 10}
    end

    test "stacks 2s attacks", %{game: game} do
      game = %{game | pending_attack: {:twos, 2}}
      cards = [Card.new(:hearts, 2)]
      result = EffectProcessor.apply_effects(game, cards)
      # Stacking: 2 + 2 = 4
      assert result.pending_attack == {:twos, 4}
    end

    test "stacks Black Jack attacks", %{game: game} do
      game = %{game | pending_attack: {:black_jacks, 5}}
      cards = [Card.new(:spades, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # Stacking: 5 + 5 = 10
      assert result.pending_attack == {:black_jacks, 10}
    end

    test "replaces different attack type (shouldn't happen in valid game)", %{game: game} do
      # This shouldn't happen in a valid game as you can't play Black Jack against 2s
      # But testing the effect processor behavior
      game = %{game | pending_attack: {:twos, 2}}
      cards = [Card.new(:spades, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result.pending_attack == {:black_jacks, 5}
    end

    test "accumulates skip counts", %{game: game} do
      game = %{game | pending_skips: 1}
      cards = [Card.new(:hearts, 7), Card.new(:spades, 7)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result.pending_skips == 3
    end

    test "regular cards have no effect", %{game: game} do
      cards = [Card.new(:hearts, 5)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result == game
    end

    test "Red Jacks have no special effect when played normally", %{game: game} do
      # Red Jacks only counter Black Jacks, otherwise they're normal cards
      cards = [Card.new(:hearts, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result == game
    end

    test "Red Jack cancels Black Jack attack", %{game: game} do
      game = %{game | pending_attack: {:black_jacks, 5}}
      # One Red Jack
      cards = [Card.new(:hearts, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # One Red Jack cancels 5 cards, reducing 5 to 0
      assert result.pending_attack == nil
    end

    test "Red Jack partially reduces Black Jack attack", %{game: game} do
      game = %{game | pending_attack: {:black_jacks, 10}}
      # One Red Jack
      cards = [Card.new(:hearts, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # One Red Jack reduces by 5: 10 - 5 = 5
      assert result.pending_attack == {:black_jacks, 5}
    end

    test "multiple Red Jacks stack their cancellation", %{game: game} do
      game = %{game | pending_attack: {:black_jacks, 15}}
      # Two Red Jacks
      cards = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # Two Red Jacks reduce by 10: 15 - 10 = 5
      assert result.pending_attack == {:black_jacks, 5}
    end

    test "Red Jacks can over-cancel Black Jack attack", %{game: game} do
      game = %{game | pending_attack: {:black_jacks, 5}}
      # Two Red Jacks
      cards = [Card.new(:hearts, 11), Card.new(:diamonds, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # Two Red Jacks reduce by 10, more than the 5 penalty
      assert result.pending_attack == nil
    end

    test "Red Jacks don't affect 2s attacks", %{game: game} do
      game = %{game | pending_attack: {:twos, 4}}
      # Red Jack
      cards = [Card.new(:hearts, 11)]
      result = EffectProcessor.apply_effects(game, cards)
      # Red Jack has no effect on 2s attack - processes normally
      assert result.pending_attack == {:twos, 4}
    end

    test "multiple stacked cards of same rank", %{game: game} do
      # Three 7s
      cards = [Card.new(:hearts, 7), Card.new(:diamonds, 7), Card.new(:clubs, 7)]
      result = EffectProcessor.apply_effects(game, cards)
      assert result.pending_skips == 3
    end
  end
end
