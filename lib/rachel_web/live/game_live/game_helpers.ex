defmodule RachelWeb.GameLive.GameHelpers do
  @moduledoc """
  Game logic helper functions for GameLive.
  Handles playability checks and game state queries.
  """

  alias Rachel.Game.Rules

  @doc """
  Checks if player has any valid plays available.
  """
  def has_valid_plays?(game, player) do
    top_card = hd(game.discard_pile)

    Enum.any?(player.hand, fn card ->
      if game.pending_attack do
        {attack_type, _} = game.pending_attack
        Rules.can_counter_attack?(card, attack_type)
      else
        Rules.can_play_card?(card, top_card, game.nominated_suit)
      end
    end)
  end

  @doc """
  Checks if a card is playable given current selection.
  """
  def card_playable?(game, card, selected_cards) do
    if Enum.empty?(selected_cards) do
      card_playable_standalone?(game, card)
    else
      can_stack_with_selected?(card, selected_cards)
    end
  end

  @doc """
  Checks if a single card can be played on its own.
  """
  def card_playable_standalone?(game, card) do
    top_card = hd(game.discard_pile)

    if game.pending_attack do
      {attack_type, _} = game.pending_attack
      Rules.can_counter_attack?(card, attack_type)
    else
      Rules.can_play_card?(card, top_card, game.nominated_suit)
    end
  end

  @doc """
  Checks if a card can stack with already selected cards.
  """
  def can_stack_with_selected?(card, selected_cards) do
    first_selected = hd(selected_cards)
    card.rank == first_selected.rank && card not in selected_cards
  end

  @doc """
  Checks if played cards need suit nomination (Aces).
  """
  def needs_suit_nomination?(cards) do
    Enum.any?(cards, &(&1.rank == 14))
  end

  @doc """
  Gets smart button text based on game state.
  """
  def smart_button_text(game, player) do
    cond do
      game.pending_attack != nil ->
        {_, count} = game.pending_attack
        "Draw #{count} Cards"

      has_valid_plays?(game, player) ->
        "Draw Card (optional)"

      true ->
        "Draw Card"
    end
  end

  @doc """
  Gets the current player from game state.
  """
  def current_player(game) do
    Enum.at(game.players, game.current_player_index)
  end

  @doc """
  Gets the current player's name.
  """
  def current_player_name(game) do
    current_player(game).name
  end
end
