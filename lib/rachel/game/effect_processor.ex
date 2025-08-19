defmodule Rachel.Game.EffectProcessor do
  @moduledoc """
  Processes card effects in a clean, functional way.
  Extracted from GameState for better separation of concerns.
  """

  alias Rachel.Game.{Card, Rules}

  @doc """
  Applies all effects from played cards to the game state.
  """
  def apply_effects(game, cards, nominated_suit \\ nil) do
    # Check if we're playing Red Jacks against a Black Jack attack
    if game.pending_attack do
      {attack_type, _count} = game.pending_attack

      if attack_type == :black_jacks && Enum.any?(cards, &Card.red_jack?/1) do
        # Red Jacks cancel Black Jack attacks
        apply_red_jack_cancellation(game, cards)
      else
        # Normal effect processing
        apply_normal_effects(game, cards, nominated_suit)
      end
    else
      # No pending attack, process normally
      apply_normal_effects(game, cards, nominated_suit)
    end
  end

  defp apply_normal_effects(game, cards, nominated_suit) do
    effects = Rules.calculate_effects(cards)

    # Add suit nomination for Aces if provided
    effects =
      if effects[:nominate_suit] && nominated_suit do
        Map.put(effects, :nominated_suit, nominated_suit)
      else
        effects
      end

    game
    |> apply_attack(effects[:attack])
    |> apply_skip(effects[:skip])
    |> apply_reverse(effects[:reverse])
    |> apply_suit_nomination(effects[:nominated_suit])
  end

  defp apply_red_jack_cancellation(game, cards) do
    red_jack_count = Enum.count(cards, &Card.red_jack?/1)
    new_attack = Rules.reduce_attack(game.pending_attack, red_jack_count)
    %{game | pending_attack: new_attack}
  end

  # Effect application functions

  defp apply_attack(game, nil), do: game

  defp apply_attack(game, attack) do
    new_attack =
      case {game.pending_attack, attack} do
        {nil, attack} -> attack
        {{:twos, existing}, {:twos, new}} -> {:twos, existing + new}
        {{:black_jacks, existing}, {:black_jacks, new}} -> {:black_jacks, existing + new}
        # Replace different attack type
        _ -> attack
      end

    %{game | pending_attack: new_attack}
  end

  defp apply_skip(game, nil), do: game

  defp apply_skip(game, skip_count) do
    %{game | pending_skips: game.pending_skips + skip_count}
  end

  defp apply_reverse(game, nil), do: game

  defp apply_reverse(game, true) do
    new_direction = if game.direction == :clockwise, do: :counter_clockwise, else: :clockwise
    %{game | direction: new_direction}
  end

  defp apply_suit_nomination(game, nil), do: game

  defp apply_suit_nomination(game, suit) do
    %{game | nominated_suit: suit}
  end
end
