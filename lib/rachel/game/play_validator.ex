defmodule Rachel.Game.PlayValidator do
  @moduledoc """
  Handles all play validation logic extracted from GameState.
  Clean, focused validation functions.
  """

  alias Rachel.Game.Rules

  @doc """
  Validates if a player can make a play.
  """
  def validate_play(game, player_id, cards) do
    with :ok <- validate_no_duplicates(cards),
         {:ok, player_idx} <- find_player(game, player_id),
         :ok <- validate_current_player(game, player_idx),
         :ok <- validate_player_active(game, player_idx),
         :ok <- validate_cards_in_hand(game, player_idx, cards) do
      validate_play_rules(game, cards)
    end
  end

  @doc """
  Validates if a player can draw cards.
  """
  def validate_draw(game, player_id) do
    with {:ok, player_idx} <- find_player(game, player_id),
         :ok <- validate_current_player(game, player_idx) do
      validate_player_active(game, player_idx)
    end
  end

  # Private validation functions

  defp validate_no_duplicates(cards) do
    frequencies = Enum.frequencies(cards)
    duplicates = Enum.filter(frequencies, fn {_card, count} -> count > 1 end)

    if Enum.any?(duplicates) do
      {:error, :duplicate_cards_in_play}
    else
      :ok
    end
  end

  defp find_player(game, player_id) do
    case Enum.find_index(game.players, &(&1.id == player_id)) do
      nil -> {:error, :player_not_found}
      idx -> {:ok, idx}
    end
  end

  defp validate_current_player(game, player_idx) do
    if player_idx == game.current_player_index do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp validate_player_active(game, player_idx) do
    player = Enum.at(game.players, player_idx)

    if player.status == :won do
      {:error, :player_already_won}
    else
      :ok
    end
  end

  defp validate_cards_in_hand(game, player_idx, cards) do
    player = Enum.at(game.players, player_idx)

    if Enum.all?(cards, &(&1 in player.hand)) do
      :ok
    else
      {:error, :cards_not_in_hand}
    end
  end

  defp validate_play_rules(game, cards) do
    cond do
      not Rules.valid_stack?(cards) -> {:error, :invalid_stack}
      game.pending_skips && game.pending_skips > 0 -> validate_skip_counter(game, cards)
      game.pending_attack -> validate_counter(game, cards)
      true -> validate_normal_play(game, cards)
    end
  end

  defp validate_skip_counter(_game, cards) do
    # When facing skips, can only play 7s
    if Rules.can_counter_skip?(hd(cards)) do
      :ok
    else
      {:error, :invalid_counter}
    end
  end

  defp validate_counter(game, cards) do
    {attack_type, _} = game.pending_attack

    if Rules.can_counter_attack?(hd(cards), attack_type) do
      :ok
    else
      {:error, :invalid_counter}
    end
  end

  defp validate_normal_play(game, cards) do
    top = hd(game.discard_pile)

    if Rules.can_play_card?(hd(cards), top, game.nominated_suit) do
      :ok
    else
      {:error, :invalid_play}
    end
  end
end
