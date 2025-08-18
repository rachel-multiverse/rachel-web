defmodule Rachel.Game.Card do
  @moduledoc """
  Represents a playing card in Rachel.
  """

  import Bitwise

  @type suit :: :hearts | :diamonds | :clubs | :spades
  # 11 = Jack, 12 = Queen, 13 = King, 14 = Ace
  @type rank :: 2..14

  @type t :: %__MODULE__{
          suit: suit(),
          rank: rank()
        }

  defstruct [:suit, :rank]

  @suits [:hearts, :diamonds, :clubs, :spades]
  @ranks 2..14

  @doc """
  Creates a new card with the given suit and rank.
  """
  def new(suit, rank) when suit in @suits and rank in @ranks do
    %__MODULE__{suit: suit, rank: rank}
  end

  @doc """
  Returns all 52 cards in a standard deck.
  """
  def deck do
    for suit <- @suits, rank <- @ranks do
      new(suit, rank)
    end
  end

  @doc """
  Checks if a card is a black jack (spades or clubs).
  """
  def black_jack?(%__MODULE__{suit: suit, rank: 11}) when suit in [:clubs, :spades], do: true
  def black_jack?(_), do: false

  @doc """
  Checks if a card is a red jack (hearts or diamonds).
  """
  def red_jack?(%__MODULE__{suit: suit, rank: 11}) when suit in [:hearts, :diamonds], do: true
  def red_jack?(_), do: false

  @doc """
  Checks if two cards match by suit or rank (for basic play validation).
  """
  def matches?(%__MODULE__{suit: suit1}, %__MODULE__{suit: suit2}) when suit1 == suit2, do: true
  def matches?(%__MODULE__{rank: rank1}, %__MODULE__{rank: rank2}) when rank1 == rank2, do: true
  def matches?(_, _), do: false

  @doc """
  Returns the display string for a card.
  """
  def display(%__MODULE__{suit: suit, rank: rank}) do
    "#{rank_display(rank)}#{suit_symbol(suit)}"
  end

  @doc """
  Encodes a card as a single byte for the binary protocol.
  Bits 7-6: Suit (00=Hearts, 01=Diamonds, 10=Clubs, 11=Spades)
  Bits 5-0: Rank (2-14)
  """
  def encode(%__MODULE__{suit: suit, rank: rank}) do
    suit_bits =
      case suit do
        :hearts -> 0x00
        :diamonds -> 0x40
        :clubs -> 0x80
        :spades -> 0xC0
      end

    suit_bits + rank
  end

  @doc """
  Decodes a byte into a card.
  """
  def decode(byte) when is_integer(byte) do
    suit =
      case byte &&& 0xC0 do
        0x00 -> :hearts
        0x40 -> :diamonds
        0x80 -> :clubs
        0xC0 -> :spades
      end

    rank = byte &&& 0x3F

    if rank in @ranks do
      {:ok, new(suit, rank)}
    else
      {:error, :invalid_rank}
    end
  end

  # Private helpers

  defp rank_display(11), do: "J"
  defp rank_display(12), do: "Q"
  defp rank_display(13), do: "K"
  defp rank_display(14), do: "A"
  defp rank_display(rank), do: to_string(rank)

  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"
  defp suit_symbol(:spades), do: "♠"
end
