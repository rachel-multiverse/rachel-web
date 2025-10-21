defmodule Rachel.Game.GameState do
  @moduledoc """
  Manages the complete state of a Rachel game.
  """

  require Logger
  alias Rachel.Game.{Card, Deck, DeckOperations, EffectProcessor, PlayValidator, TurnManager}

  @type status :: :waiting | :playing | :finished
  @type direction :: :clockwise | :counter_clockwise

  @type player :: %{
          id: String.t(),
          user_id: integer() | nil,
          name: String.t(),
          hand: list(Card.t()),
          type: :human | :ai,
          status: :playing | :won,
          difficulty: atom() | nil
        }

  @type t :: %__MODULE__{
          id: String.t(),
          players: list(player()),
          deck: list(Card.t()),
          discard_pile: list(Card.t()),
          current_player_index: non_neg_integer(),
          direction: direction(),
          pending_attack: {atom(), non_neg_integer()} | nil,
          pending_skips: non_neg_integer(),
          nominated_suit: Card.suit() | nil,
          status: status(),
          winners: list(String.t()),
          turn_count: non_neg_integer(),
          created_at: DateTime.t(),
          last_action_at: DateTime.t(),
          deck_count: pos_integer(),
          expected_total_cards: pos_integer()
        }

  defstruct [
    :id,
    players: [],
    deck: [],
    discard_pile: [],
    current_player_index: 0,
    direction: :clockwise,
    pending_attack: nil,
    pending_skips: 0,
    nominated_suit: nil,
    status: :waiting,
    winners: [],
    turn_count: 0,
    created_at: nil,
    last_action_at: nil,
    deck_count: 1,
    expected_total_cards: 52
  ]

  @doc """
  Creates a new game state with the given players.
  Players can be:
    - Strings (anonymous human): {:anonymous, name}
    - Authenticated user: {:user, user_id, name}
    - AI player: {:ai, name, difficulty}
    - Map (for testing): %{id: ..., user_id: ..., name: ..., ...}

  Options:
    - deck_count: number of decks to use (default: 1)
  """
  def new(player_list, opts \\ []) when is_list(player_list) do
    deck_count = Keyword.get(opts, :deck_count, 1)

    players =
      Enum.map(player_list, fn
        {:ai, name, difficulty} ->
          %{
            id: Ecto.UUID.generate(),
            user_id: nil,
            name: name,
            hand: [],
            type: :ai,
            difficulty: difficulty,
            status: :playing
          }

        {:user, user_id, name} when is_integer(user_id) ->
          %{
            id: Ecto.UUID.generate(),
            user_id: user_id,
            name: name,
            hand: [],
            type: :human,
            difficulty: nil,
            status: :playing
          }

        {:anonymous, name} when is_binary(name) ->
          %{
            id: Ecto.UUID.generate(),
            user_id: nil,
            name: name,
            hand: [],
            type: :human,
            difficulty: nil,
            status: :playing
          }

        # Backwards compatibility: plain string means anonymous
        name when is_binary(name) ->
          %{
            id: Ecto.UUID.generate(),
            user_id: nil,
            name: name,
            hand: [],
            type: :human,
            difficulty: nil,
            status: :playing
          }

        player_map when is_map(player_map) ->
          # Allow pre-formed player maps (for testing)
          # Ensure user_id field exists
          Map.put_new(player_map, :user_id, nil)
      end)

    %__MODULE__{
      id: Ecto.UUID.generate(),
      players: players,
      status: :waiting,
      created_at: DateTime.utc_now(),
      last_action_at: DateTime.utc_now(),
      deck_count: deck_count,
      expected_total_cards: deck_count * 52
    }
  end

  @doc """
  Starts the game by dealing cards and setting initial state.
  """
  def start_game(%__MODULE__{players: players, deck_count: deck_count} = game) do
    player_count = length(players)
    deck = Deck.new(deck_count)

    # Debug logging
    Logger.info(
      "Starting game with #{player_count} players, #{deck_count} deck(s), deck size: #{length(deck)}"
    )

    # Deal cards to players
    {hands, remaining_deck} = Deck.deal(deck, player_count)

    # Debug logging
    total_dealt = Enum.sum(Enum.map(hands, &length/1))
    Logger.info("Dealt #{total_dealt} cards, remaining deck: #{length(remaining_deck)}")

    # Give each player their hand
    players_with_hands =
      players
      |> Enum.zip(hands)
      |> Enum.map(fn {player, hand} ->
        Map.put(player, :hand, hand)
      end)

    # Draw first card for discard pile
    {first_card, final_deck} = Deck.draw_one(remaining_deck)

    # Debug logging
    total_in_hands = players_with_hands |> Enum.map(&length(&1.hand)) |> Enum.sum()

    Logger.info(
      "Final setup - Cards in hands: #{total_in_hands}, Deck: #{length(final_deck)}, Discard: 1, Total: #{total_in_hands + length(final_deck) + 1}"
    )

    %{
      game
      | players: players_with_hands,
        deck: final_deck,
        discard_pile: [first_card],
        status: :playing,
        current_player_index: Enum.random(0..(player_count - 1)),
        last_action_at: DateTime.utc_now()
    }
  end

  @doc """
  Executes a play card action for the current player.
  """
  def play_cards(%__MODULE__{} = game, player_id, cards, nominated_suit \\ nil) do
    with :ok <- PlayValidator.validate_play(game, player_id, cards),
         {:ok, player_idx} <- get_player_index(game, player_id) do
      # Clear any existing nomination BEFORE playing (it was for this turn)
      game_after_clear = if game.nominated_suit, do: %{game | nominated_suit: nil}, else: game
      
      {:ok,
       game_after_clear
       |> remove_cards_from_player(player_idx, cards)
       |> add_cards_to_discard(cards)
       |> EffectProcessor.apply_effects(cards, nominated_suit)  # May set new nomination
       |> TurnManager.check_winner(player_idx)
       |> TurnManager.advance_turn()  # Keeps new nominations
       |> update_timestamp()
       |> increment_turn_count()}
    end
  end

  @doc """
  Executes a draw card action for the current player.
  """
  def draw_cards(%__MODULE__{} = game, player_id, reason \\ :cannot_play) do
    with :ok <- PlayValidator.validate_draw(game, player_id),
         {:ok, player_idx} <- get_player_index(game, player_id) do
      draw_count = calculate_draw_count(game, reason)

      {:ok, {drawn, new_deck, new_discard}} =
        DeckOperations.draw_cards(game.deck, game.discard_pile, draw_count)

      players = DeckOperations.add_to_hand(game.players, player_idx, drawn)

      game =
        %{game | players: players, deck: new_deck, discard_pile: new_discard}
        |> clear_pending_attack(reason)
        |> update_timestamp()

      if reason == :attack do
        {:ok, game}
      else
        {:ok, game |> TurnManager.advance_turn() |> increment_turn_count()}
      end
    end
  end

  @doc """
  Gets the current player.
  """
  def current_player(%__MODULE__{players: players, current_player_index: index}) do
    Enum.at(players, index)
  end

  @doc """
  Gets the top card of the discard pile.
  """
  def top_card(%__MODULE__{discard_pile: [top | _]}), do: top
  def top_card(_), do: nil

  # Private functions

  defp get_player_index(game, player_id) do
    case Enum.find_index(game.players, &(&1.id == player_id)) do
      nil -> {:error, :player_not_found}
      index -> {:ok, index}
    end
  end

  defp remove_cards_from_player(game, player_idx, cards) do
    players = DeckOperations.remove_from_hand(game.players, player_idx, cards)
    %{game | players: players}
  end

  defp add_cards_to_discard(game, cards) do
    %{game | discard_pile: cards ++ game.discard_pile}
  end

  defp calculate_draw_count(_game, :cannot_play), do: 1

  defp calculate_draw_count(game, :attack) do
    case game.pending_attack do
      {:twos, count} -> count
      {:black_jacks, count} -> count
      _ -> 1
    end
  end

  defp clear_pending_attack(game, :attack) do
    %{game | pending_attack: nil}
  end

  defp clear_pending_attack(game, _), do: game

  defp update_timestamp(game) do
    %{game | last_action_at: DateTime.utc_now()}
  end

  defp increment_turn_count(game) do
    %{game | turn_count: game.turn_count + 1}
  end

  @doc """
  Validates game state integrity.
  """
  def validate_integrity(%__MODULE__{status: :waiting}), do: :ok

  def validate_integrity(game) do
    DeckOperations.validate_card_count(
      game.players,
      game.deck,
      game.discard_pile,
      game.expected_total_cards
    )
  end

  @doc """
  Checks if the game should end.
  """
  def should_end?(game), do: TurnManager.should_end?(game)
end
