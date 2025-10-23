defmodule RachelWeb.GameLive.ViewHelpersTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.Card
  alias RachelWeb.GameLive.ViewHelpers

  describe "card_color_class/1" do
    test "returns red color for hearts" do
      card = Card.new(:hearts, 5)
      assert ViewHelpers.card_color_class(card) == "text-red-500"
    end

    test "returns red color for diamonds" do
      card = Card.new(:diamonds, 10)
      assert ViewHelpers.card_color_class(card) == "text-red-500"
    end

    test "returns gray color for clubs" do
      card = Card.new(:clubs, 7)
      assert ViewHelpers.card_color_class(card) == "text-gray-900"
    end

    test "returns gray color for spades" do
      card = Card.new(:spades, 3)
      assert ViewHelpers.card_color_class(card) == "text-gray-900"
    end
  end

  describe "rank_display/1" do
    test "displays Jack as J" do
      card = Card.new(:hearts, 11)
      assert ViewHelpers.rank_display(card) == "J"
    end

    test "displays Queen as Q" do
      card = Card.new(:diamonds, 12)
      assert ViewHelpers.rank_display(card) == "Q"
    end

    test "displays King as K" do
      card = Card.new(:clubs, 13)
      assert ViewHelpers.rank_display(card) == "K"
    end

    test "displays Ace as A" do
      card = Card.new(:spades, 14)
      assert ViewHelpers.rank_display(card) == "A"
    end

    test "displays number cards as strings" do
      assert ViewHelpers.rank_display(Card.new(:hearts, 2)) == "2"
      assert ViewHelpers.rank_display(Card.new(:hearts, 5)) == "5"
      assert ViewHelpers.rank_display(Card.new(:hearts, 10)) == "10"
    end
  end

  describe "suit_symbol/1" do
    test "returns heart symbol for hearts" do
      card = Card.new(:hearts, 5)
      assert ViewHelpers.suit_symbol(card) == "♥"
    end

    test "returns diamond symbol for diamonds" do
      card = Card.new(:diamonds, 5)
      assert ViewHelpers.suit_symbol(card) == "♦"
    end

    test "returns club symbol for clubs" do
      card = Card.new(:clubs, 5)
      assert ViewHelpers.suit_symbol(card) == "♣"
    end

    test "returns spade symbol for spades" do
      card = Card.new(:spades, 5)
      assert ViewHelpers.suit_symbol(card) == "♠"
    end
  end

  describe "direction_symbol/1" do
    test "returns clockwise arrow for clockwise" do
      assert ViewHelpers.direction_symbol(:clockwise) == "↻"
    end

    test "returns counter-clockwise arrow for counter_clockwise" do
      assert ViewHelpers.direction_symbol(:counter_clockwise) == "↺"
    end
  end

  describe "attack_description/1" do
    test "describes twos attack with count" do
      assert ViewHelpers.attack_description({:twos, 4}) == "Draw 4"
    end

    test "describes black jacks attack with count" do
      assert ViewHelpers.attack_description({:black_jacks, 10}) == "Draw 10"
    end

    test "handles different attack counts" do
      assert ViewHelpers.attack_description({:twos, 2}) == "Draw 2"
      assert ViewHelpers.attack_description({:black_jacks, 15}) == "Draw 15"
    end

    test "returns nil for no attack" do
      assert ViewHelpers.attack_description(nil) == nil
    end

    test "returns nil for unknown attack type" do
      assert ViewHelpers.attack_description(:unknown) == nil
    end
  end

  describe "draw_button_text/1" do
    test "returns default text when no attack" do
      game = %{pending_attack: nil}
      assert ViewHelpers.draw_button_text(game) == "Draw Card"
    end

    test "returns draw count for twos attack" do
      game = %{pending_attack: {:twos, 4}}
      assert ViewHelpers.draw_button_text(game) == "Draw 4 Cards"
    end

    test "returns draw count for black jacks attack" do
      game = %{pending_attack: {:black_jacks, 10}}
      assert ViewHelpers.draw_button_text(game) == "Draw 10 Cards"
    end
  end

  describe "error_message/1" do
    test "handles GameError struct with message" do
      error = %Rachel.Game.GameError{
        type: :invalid_play,
        message: "Cannot play that card"
      }

      assert ViewHelpers.error_message(error) == "Cannot play that card"
    end

    test "handles not_your_turn error" do
      assert ViewHelpers.error_message(:not_your_turn) == "It's not your turn"
    end

    test "handles invalid_play error" do
      assert ViewHelpers.error_message(:invalid_play) == "Invalid card play"
    end

    test "handles cards_not_in_hand error" do
      assert ViewHelpers.error_message(:cards_not_in_hand) == "Selected cards not in hand"
    end

    test "handles invalid_stack error" do
      assert ViewHelpers.error_message(:invalid_stack) ==
               "Cards must be the same rank to stack"
    end

    test "handles invalid_counter error" do
      assert ViewHelpers.error_message(:invalid_counter) == "Invalid counter for this attack"
    end

    test "handles player_not_found error" do
      assert ViewHelpers.error_message(:player_not_found) == "Player not found"
    end

    test "handles duplicate_cards_in_play error" do
      assert ViewHelpers.error_message(:duplicate_cards_in_play) ==
               "Duplicate cards selected"
    end

    test "handles unknown error types" do
      result = ViewHelpers.error_message(:unknown_error)
      assert result =~ "Error:"
      assert result =~ "unknown_error"
    end
  end
end
