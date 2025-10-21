defmodule RachelWeb.GameLive.ViewHelpers do
  @moduledoc """
  View helper functions for GameLive.
  Extracted for better organization and reusability.
  """

  alias Rachel.Game.Card

  # Card display helpers

  def card_color_class(%Card{suit: suit}) when suit in [:hearts, :diamonds] do
    "text-red-500"
  end

  def card_color_class(_), do: "text-gray-900"

  def rank_display(%Card{rank: 11}), do: "J"
  def rank_display(%Card{rank: 12}), do: "Q"
  def rank_display(%Card{rank: 13}), do: "K"
  def rank_display(%Card{rank: 14}), do: "A"
  def rank_display(%Card{rank: rank}), do: to_string(rank)

  def suit_symbol(%Card{suit: :hearts}), do: "♥"
  def suit_symbol(%Card{suit: :diamonds}), do: "♦"
  def suit_symbol(%Card{suit: :clubs}), do: "♣"
  def suit_symbol(%Card{suit: :spades}), do: "♠"

  # Game UI helpers

  def direction_symbol(:clockwise), do: "↻"
  def direction_symbol(:counter_clockwise), do: "↺"

  def attack_description({:twos, count}), do: "Draw #{count}"
  def attack_description({:black_jacks, count}), do: "Draw #{count}"
  def attack_description(_), do: nil

  def draw_button_text(%{pending_attack: nil}), do: "Draw Card"
  def draw_button_text(%{pending_attack: {_, count}}), do: "Draw #{count} Cards"

  # Error messages

  # Handle new GameError structs with detailed user-friendly messages
  def error_message(%Rachel.Game.GameError{message: message}), do: message

  # Fallback for old atom-based errors (backwards compatibility)
  def error_message(:not_your_turn), do: "It's not your turn"
  def error_message(:invalid_play), do: "Invalid card play"
  def error_message(:cards_not_in_hand), do: "Selected cards not in hand"
  def error_message(:invalid_stack), do: "Cards must be the same rank to stack"
  def error_message(:invalid_counter), do: "Invalid counter for this attack"
  def error_message(:player_not_found), do: "Player not found"
  def error_message(:duplicate_cards_in_play), do: "Duplicate cards selected"
  def error_message(other), do: "Error: #{inspect(other)}"
end
