defmodule Rachel.Game.DeckOperations do
  @moduledoc """
  Handles all deck-related operations: dealing, drawing, reshuffling.
  Extracted from GameState for better separation of concerns.
  """

  require Logger

  @doc """
  Safely draws cards with automatic reshuffling when needed.
  Returns {drawn_cards, new_deck, new_discard} or {:error, reason}
  """
  def draw_cards(deck, discard_pile, count) when count > 0 do
    available_in_deck = length(deck)

    cond do
      # Enough cards in deck
      available_in_deck >= count ->
        {drawn, remaining} = Enum.split(deck, count)
        {:ok, {drawn, remaining, discard_pile}}

      # Need to reshuffle
      length(discard_pile) > 1 ->
        reshuffle_and_draw(deck, discard_pile, count)

      # Not enough total cards - can't draw from single discard card
      true ->
        {:ok, {[], deck, discard_pile}}
    end
  end

  def draw_cards(_deck, _discard, count) when count <= 0 do
    {:ok, {[], [], []}}
  end

  defp reshuffle_and_draw(deck, [top_card | rest], count) do
    # Draw what we can from deck first
    {first_batch, _} = Enum.split(deck, length(deck))
    needed = count - length(first_batch)

    # Reshuffle discard (keeping top card)
    reshuffled = Enum.shuffle(rest)

    # Draw remaining from reshuffled
    {second_batch, new_deck} = Enum.split(reshuffled, min(needed, length(reshuffled)))

    drawn = first_batch ++ second_batch
    {:ok, {drawn, new_deck, [top_card]}}
  end

  @doc """
  Updates a player's hand after drawing cards.
  """
  def add_to_hand(players, player_index, cards) do
    List.update_at(players, player_index, fn player ->
      %{player | hand: player.hand ++ cards}
    end)
  end

  @doc """
  Removes cards from a player's hand precisely (handling duplicates correctly).
  """
  def remove_from_hand(players, player_index, cards) do
    List.update_at(players, player_index, fn player ->
      new_hand = remove_cards_precisely(player.hand, cards)
      %{player | hand: new_hand}
    end)
  end

  defp remove_cards_precisely(hand, []), do: hand

  defp remove_cards_precisely(hand, [card | rest]) do
    case Enum.find_index(hand, &(&1 == card)) do
      # Card not found, continue
      nil ->
        remove_cards_precisely(hand, rest)

      index ->
        new_hand = List.delete_at(hand, index)
        remove_cards_precisely(new_hand, rest)
    end
  end

  @doc """
  Validates total card count in game.
  """
  def validate_card_count(players, deck, discard_pile, expected_total) do
    cards_in_hands = players |> Enum.map(&length(&1.hand)) |> Enum.sum()
    total = cards_in_hands + length(deck) + length(discard_pile)

    if total == expected_total do
      :ok
    else
      Logger.warning("Card count mismatch: #{total} cards (expected #{expected_total})")
      {:error, {:card_count, total}}
    end
  end
end
