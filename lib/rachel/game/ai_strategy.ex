defmodule Rachel.Game.AIStrategy do
  @moduledoc """
  AI strategy logic extracted from AIPlayer for better maintainability.
  Simple, focused functions for AI decision making.
  """

  alias Rachel.Game.Card

  @doc """
  Scores a potential play based on difficulty and game state.
  """
  def score_play(_cards, _hand, :easy) do
    # Easy AI: Random play
    :rand.uniform(100)
  end

  def score_play(cards, hand, difficulty) when difficulty in [:medium, :hard] do
    first_card = hd(cards)
    stack_size = length(cards)
    remaining_cards = length(hand) - stack_size

    base_score = card_value(first_card) * stack_size
    stack_bonus = stack_bonus(stack_size, remaining_cards, difficulty)
    strategy_bonus = strategy_bonus(first_card, remaining_cards, difficulty)

    base_score + stack_bonus + strategy_bonus
  end

  # Attack cards
  defp card_value(%{rank: 2}), do: 30
  # Skip cards
  defp card_value(%{rank: 7}), do: 25
  # Aces for suit control
  defp card_value(%{rank: 14}), do: 35
  # Queens for direction
  defp card_value(%{rank: 12}), do: 20

  defp card_value(card) do
    # Black jacks vs regular
    if Card.black_jack?(card), do: 40, else: 10
  end

  defp stack_bonus(stack_size, remaining, :medium) when remaining > 3 do
    stack_size * 5
  end

  defp stack_bonus(stack_size, remaining, :hard) when remaining > 2 do
    stack_size * 10
  end

  defp stack_bonus(_, _, _), do: 0

  defp strategy_bonus(card, remaining, :hard) do
    cond do
      # Keep defensive cards when low
      remaining < 3 and card.rank in [2, 7, 11] -> -20
      # Bonus for finishing the game
      remaining == 0 -> 100
      # Penalty for red jacks (keep for defense)
      Card.red_jack?(card) -> -15
      true -> 0
    end
  end

  defp strategy_bonus(_, _, _), do: 0

  @doc """
  Chooses suit for Aces based on remaining hand.
  """
  def choose_suit(_remaining_hand, :easy) do
    Enum.random([:hearts, :diamonds, :clubs, :spades])
  end

  def choose_suit(remaining_hand, _difficulty) do
    remaining_hand
    |> Enum.group_by(& &1.suit)
    |> Enum.max_by(fn {_suit, cards} -> length(cards) end, fn -> {:hearts, []} end)
    |> elem(0)
  end

  @doc """
  Chooses counter cards for attacks based on difficulty.
  """
  def choose_counter(counter_cards, _attack_type, :easy) do
    [Enum.random(counter_cards)]
  end

  def choose_counter(counter_cards, _attack_type, :medium) do
    # Play about half the counters
    by_rank = Enum.group_by(counter_cards, & &1.rank)
    {_rank, cards} = Enum.random(by_rank)
    Enum.take(cards, div(length(cards) + 1, 2))
  end

  def choose_counter(counter_cards, :twos, :hard) do
    # Stack all 2s to maximize counter-attack
    counter_cards
  end

  def choose_counter(counter_cards, :black_jacks, :hard) do
    red_jacks = Enum.filter(counter_cards, &Card.red_jack?/1)

    if Enum.any?(red_jacks) do
      # Use minimum red jacks needed
      [hd(red_jacks)]
    else
      # Stack black jacks
      counter_cards
    end
  end
end
