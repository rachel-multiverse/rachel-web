defmodule Rachel.Game.Rules do
  @moduledoc """
  Enforces the sacred rules of Rachel.
  This module is the single source of truth for game rules.
  """

  alias Rachel.Game.Card

  @doc """
  Determines if a card can be played on the current discard pile.
  Takes into account suit nominations from Aces.
  """
  def can_play_card?(card, top_card, nominated_suit \\ nil)

  # If there's a suit nomination from an Ace, must match nominated suit OR play another Ace (rank match)
  def can_play_card?(card, top_card, nominated_suit) when not is_nil(nominated_suit) do
    card.suit == nominated_suit or (card.rank == 14 and top_card.rank == 14)
  end

  # Normal matching: same suit or same rank
  def can_play_card?(card, top_card, nil) do
    Card.matches?(card, top_card)
  end

  @doc """
  Checks if a player can respond to an attack with the given card.
  """
  def can_counter_attack?(card, attack_type)

  # 2s can only be countered with other 2s
  def can_counter_attack?(%Card{rank: 2}, :twos), do: true
  
  # Black Jacks can be countered with other Black Jacks or Red Jacks
  def can_counter_attack?(card, :black_jacks) do
    Card.black_jack?(card) or Card.red_jack?(card)
  end
  
  def can_counter_attack?(_, _), do: false
  
  @doc """
  Checks if a player can respond to skips with 7s.
  Separate from attacks because skips work differently.
  """
  def can_counter_skip?(%Card{rank: 7}), do: true
  def can_counter_skip?(_), do: false

  @doc """
  Validates that all cards in a stack are the same rank.
  """
  def valid_stack?(cards) when is_list(cards) do
    case cards do
      [] -> false
      [_] -> true
      [first | rest] -> 
        Enum.all?(rest, fn card -> card.rank == first.rank end)
    end
  end

  @doc """
  Calculates the effect of playing cards.
  Returns a map with the effects to apply.
  """
  def calculate_effects(cards) when is_list(cards) do
    case cards do
      [] -> 
        %{}
      
      [%Card{rank: 2} | _] = twos ->
        %{attack: {:twos, length(twos) * 2}}
      
      [%Card{rank: 7} | _] = sevens ->
        %{skip: length(sevens)}
      
      [%Card{rank: 12} | _] = queens ->
        # Odd number of queens reverses direction
        if rem(length(queens), 2) == 1 do
          %{reverse: true}
        else
          %{}
        end
      
      [%Card{rank: 14} | _] ->
        # Aces nominate suit - handled separately
        %{nominate_suit: true}
      
      [first | _] ->
        # Check for Black Jacks
        if Card.black_jack?(first) do
          black_jack_count = Enum.count(cards, &Card.black_jack?/1)
          %{attack: {:black_jacks, black_jack_count * 5}}
        else
          %{}
        end
    end
  end

  @doc """
  Determines how many cards to deal based on player count.
  """
  def cards_per_player(player_count) do
    case player_count do
      n when n in 2..5 -> 7
      n when n in 6..7 -> 6
      8 -> 5
      _ -> {:error, :invalid_player_count}
    end
  end

  @doc """
  Checks if a player must play a card (mandatory play rule).
  Returns true if the player has any valid play.
  """
  def must_play?(hand, top_card, nominated_suit, pending_attack) do
    has_valid_play?(hand, top_card, nominated_suit, pending_attack)
  end

  @doc """
  Checks if a player has any valid play.
  Handles attacks and skips separately.
  """
  def has_valid_play?(hand, top_card, nominated_suit, pending_attack, pending_skips \\ 0) do
    cond do
      # If facing skips, can only play 7s
      pending_skips > 0 ->
        Enum.any?(hand, &can_counter_skip?/1)
      
      # If facing an attack, can only play counter cards
      pending_attack != nil ->
        {attack_type, _count} = pending_attack
        Enum.any?(hand, &can_counter_attack?(&1, attack_type))
      
      # Otherwise check for normal plays
      true ->
        Enum.any?(hand, &can_play_card?(&1, top_card, nominated_suit))
    end
  end

  @doc """
  Reduces attack penalty when Red Jacks counter Black Jacks.
  """
  def reduce_attack({:black_jacks, count}, red_jack_count) do
    new_count = max(0, count - (red_jack_count * 5))
    if new_count > 0 do
      {:black_jacks, new_count}
    else
      nil
    end
  end
  
  def reduce_attack(attack, _), do: attack

  @doc """
  Determines the next player index based on direction and skips.
  """
  def next_player_index(current_index, player_count, direction, skip_count \\ 0) do
    step = if direction == :clockwise, do: 1, else: -1
    steps_to_take = 1 + skip_count
    
    next_idx = current_index + (step * steps_to_take)
    
    # Proper modulo for negative numbers
    Integer.mod(next_idx, player_count)
  end

  @doc """
  Validates a suit nomination.
  """
  def valid_suit?(suit) do
    suit in [:hearts, :diamonds, :clubs, :spades]
  end

  @doc """
  Checks if the game should end (player has no cards).
  """
  def game_over?(player_hand) do
    Enum.empty?(player_hand)
  end

  @doc """
  Determines if a set of cards can be played together.
  Must be same rank for stacking.
  """
  def can_stack_cards?(cards) do
    valid_stack?(cards)
  end

  @doc """
  Get the attack type from a card rank.
  """
  def attack_type_from_rank(2), do: :twos
  def attack_type_from_rank(7), do: :sevens
  def attack_type_from_rank(11), do: :black_jacks  # Only for black suits
  def attack_type_from_rank(_), do: nil
end