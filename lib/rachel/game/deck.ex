defmodule Rachel.Game.Deck do
  @moduledoc """
  Manages the deck of cards for Rachel.
  """

  alias Rachel.Game.Card

  @doc """
  Creates a new shuffled deck of 52 cards.
  """
  def new do
    Card.deck()
    |> Enum.shuffle()
  end

  @doc """
  Deals cards to players according to the rules.
  Returns {hands, remaining_deck}.
  """
  def deal(deck, player_count) do
    cards_per_player =
      case player_count do
        n when n in 2..5 -> 7
        n when n in 6..7 -> 6
        8 -> 5
        _ -> raise "Invalid player count: #{player_count}"
      end

    {hands, remaining} = deal_hands(deck, player_count, cards_per_player)
    {hands, remaining}
  end

  @doc """
  Draws a specific number of cards from the deck.
  Returns {drawn_cards, remaining_deck}.
  """
  def draw(deck, count) when count > 0 do
    Enum.split(deck, count)
  end

  def draw(deck, _count), do: {[], deck}

  @doc """
  Draws a single card from the deck.
  Returns {card, remaining_deck} or {nil, deck} if deck is empty.
  """
  def draw_one([card | rest]) do
    {card, rest}
  end

  def draw_one([]) do
    {nil, []}
  end

  @doc """
  Reshuffles the discard pile (minus the top card) to form a new deck.
  Used when the draw pile is empty.
  """
  def reshuffle_discard([top_card | rest]) when length(rest) > 0 do
    {top_card, Enum.shuffle(rest)}
  end

  def reshuffle_discard(discard) do
    # If only one card or empty, can't reshuffle
    {List.first(discard), []}
  end

  # Private functions

  defp deal_hands(deck, player_count, cards_per_player) do
    total_cards_needed = player_count * cards_per_player

    if length(deck) < total_cards_needed do
      raise "Not enough cards in deck"
    end

    {cards_to_deal, remaining} = Enum.split(deck, total_cards_needed)

    hands =
      cards_to_deal
      |> Enum.chunk_every(cards_per_player)
      |> Enum.take(player_count)

    {hands, remaining}
  end
end
