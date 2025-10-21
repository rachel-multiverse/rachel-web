defmodule Rachel.Game.GameError do
  @moduledoc """
  Structured error types for game operations with user-friendly messages.

  All game errors are returned as {:error, %GameError{}} tuples.
  """

  defstruct [:type, :message, :details]

  @type error_type ::
          :player_not_found
          | :not_your_turn
          | :cards_not_in_hand
          | :invalid_stack
          | :invalid_play
          | :invalid_counter
          | :game_not_found
          | :cannot_join
          | :invalid_status
          | :must_play
          | :must_draw

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map() | nil
        }

  @doc """
  Creates a new game error with a user-friendly message.
  """
  def new(type, details \\ %{})

  def new(:player_not_found, details) do
    %__MODULE__{
      type: :player_not_found,
      message: "Player not found in this game",
      details: details
    }
  end

  def new(:not_your_turn, %{current_player: name} = details) do
    %__MODULE__{
      type: :not_your_turn,
      message: "It's #{name}'s turn, please wait",
      details: details
    }
  end

  def new(:not_your_turn, details) do
    %__MODULE__{
      type: :not_your_turn,
      message: "It's not your turn yet",
      details: details
    }
  end

  def new(:cards_not_in_hand, %{cards: cards} = details) do
    card_names = Enum.map(cards, &card_name/1) |> Enum.join(", ")

    %__MODULE__{
      type: :cards_not_in_hand,
      message: "You don't have these cards: #{card_names}",
      details: details
    }
  end

  def new(:cards_not_in_hand, details) do
    %__MODULE__{
      type: :cards_not_in_hand,
      message: "You don't have those cards in your hand",
      details: details
    }
  end

  def new(:invalid_stack, %{cards: cards} = details) do
    %__MODULE__{
      type: :invalid_stack,
      message: "You can only play multiple cards of the same rank",
      details: details
    }
  end

  def new(:invalid_stack, details) do
    %__MODULE__{
      type: :invalid_stack,
      message: "Invalid card combination",
      details: details
    }
  end

  def new(:invalid_play, %{card: card, top_card: top, nominated_suit: suit} = details)
      when not is_nil(suit) do
    %__MODULE__{
      type: :invalid_play,
      message:
        "#{card_name(card)} doesn't match #{suit_name(suit)} (nominated suit) or #{card_name(top)}",
      details: details
    }
  end

  def new(:invalid_play, %{card: card, top_card: top} = details) do
    %__MODULE__{
      type: :invalid_play,
      message: "#{card_name(card)} doesn't match #{card_name(top)}",
      details: details
    }
  end

  def new(:invalid_play, details) do
    %__MODULE__{
      type: :invalid_play,
      message: "That card can't be played right now",
      details: details
    }
  end

  def new(:invalid_counter, %{attack_type: :twos, cards: cards} = details) do
    card_names = Enum.map(cards, &card_name/1) |> Enum.join(", ")

    %__MODULE__{
      type: :invalid_counter,
      message: "You can only counter the 2s attack with more 2s, not #{card_names}",
      details: details
    }
  end

  def new(:invalid_counter, %{attack_type: :black_jacks, cards: cards} = details) do
    card_names = Enum.map(cards, &card_name/1) |> Enum.join(", ")

    %__MODULE__{
      type: :invalid_counter,
      message:
        "You can only counter the Black Jack attack with more Black Jacks or Red Jacks, not #{card_names}",
      details: details
    }
  end

  def new(:invalid_counter, details) do
    %__MODULE__{
      type: :invalid_counter,
      message: "You can't counter this attack with those cards",
      details: details
    }
  end

  def new(:game_not_found, details) do
    %__MODULE__{
      type: :game_not_found,
      message: "Game not found - it may have ended or been deleted",
      details: details
    }
  end

  def new(:cannot_join, %{reason: :game_full} = details) do
    %__MODULE__{
      type: :cannot_join,
      message: "This game is full (maximum 8 players)",
      details: details
    }
  end

  def new(:cannot_join, %{reason: :already_started} = details) do
    %__MODULE__{
      type: :cannot_join,
      message: "This game has already started",
      details: details
    }
  end

  def new(:cannot_join, details) do
    %__MODULE__{
      type: :cannot_join,
      message: "You can't join this game right now",
      details: details
    }
  end

  def new(:invalid_status, %{current: current, expected: expected} = details) do
    %__MODULE__{
      type: :invalid_status,
      message: "Game is #{current}, expected #{expected}",
      details: details
    }
  end

  def new(:invalid_status, details) do
    %__MODULE__{
      type: :invalid_status,
      message: "Game is in the wrong state for this action",
      details: details
    }
  end

  def new(:must_play, %{playable_cards: cards} = details) when length(cards) > 0 do
    card_names = Enum.map(cards, &card_name/1) |> Enum.join(", ")

    %__MODULE__{
      type: :must_play,
      message: "You must play one of these cards: #{card_names}",
      details: details
    }
  end

  def new(:must_play, details) do
    %__MODULE__{
      type: :must_play,
      message: "You have cards you can play - you must play before drawing",
      details: details
    }
  end

  def new(:must_draw, %{pending_attack: {type, count}} = details) do
    attack_name =
      case type do
        :twos -> "2s"
        :black_jacks -> "Black Jacks"
        _ -> "attack"
      end

    %__MODULE__{
      type: :must_draw,
      message: "You must draw #{count} cards from the #{attack_name} attack or counter it",
      details: details
    }
  end

  def new(:must_draw, details) do
    %__MODULE__{
      type: :must_draw,
      message: "You must draw cards from the attack",
      details: details
    }
  end

  # Helper functions for formatting

  defp card_name(%{suit: suit, rank: rank}) do
    "#{rank_name(rank)} of #{suit_name(suit)}"
  end

  defp rank_name("A"), do: "Ace"
  defp rank_name("K"), do: "King"
  defp rank_name("Q"), do: "Queen"
  defp rank_name("J"), do: "Jack"
  defp rank_name(rank), do: rank

  defp suit_name(:hearts), do: "Hearts"
  defp suit_name(:diamonds), do: "Diamonds"
  defp suit_name(:clubs), do: "Clubs"
  defp suit_name(:spades), do: "Spades"
  defp suit_name(suit) when is_atom(suit), do: suit |> Atom.to_string() |> String.capitalize()

  @doc """
  Converts an error to a simple string message.
  """
  def to_string(%__MODULE__{message: message}), do: message

  @doc """
  Converts an error to a map for JSON responses.
  """
  def to_map(%__MODULE__{type: type, message: message, details: details}) do
    %{
      error: type,
      message: message,
      details: details
    }
  end
end
