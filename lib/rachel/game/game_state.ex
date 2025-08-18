defmodule Rachel.Game.GameState do
  @moduledoc """
  Manages the complete state of a Rachel game.
  """

  alias Rachel.Game.{Card, Deck, Rules}

  @type status :: :waiting | :playing | :finished
  @type direction :: :clockwise | :counter_clockwise

  @type t :: %__MODULE__{
    id: String.t(),
    players: list(map()),
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
    last_action_at: DateTime.t()
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
    last_action_at: nil
  ]

  @doc """
  Creates a new game state with the given players.
  """
  def new(player_names) when is_list(player_names) do
    players = Enum.map(player_names, fn name ->
      %{
        id: Ecto.UUID.generate(),
        name: name,
        hand: [],
        type: :human,
        status: :playing
      }
    end)

    %__MODULE__{
      id: Ecto.UUID.generate(),
      players: players,
      status: :waiting,
      created_at: DateTime.utc_now(),
      last_action_at: DateTime.utc_now()
    }
  end

  @doc """
  Starts the game by dealing cards and setting initial state.
  """
  def start_game(%__MODULE__{players: players} = game) do
    player_count = length(players)
    deck = Deck.new()
    
    # Deal cards to players
    {hands, remaining_deck} = Deck.deal(deck, player_count)
    
    # Give each player their hand
    players_with_hands = players
    |> Enum.zip(hands)
    |> Enum.map(fn {player, hand} ->
      Map.put(player, :hand, hand)
    end)
    
    # Draw first card for discard pile
    {first_card, final_deck} = Deck.draw_one(remaining_deck)
    
    %{game | 
      players: players_with_hands,
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
    with {:ok, player_index} <- get_player_index(game, player_id),
         :ok <- validate_current_player(game, player_index),
         :ok <- validate_cards_in_hand(game, player_index, cards),
         :ok <- validate_play(game, cards),
         {:ok, effects} <- calculate_and_validate_effects(cards, nominated_suit) do
      
      {:ok, game
      |> remove_cards_from_hand(player_index, cards)
      |> add_cards_to_discard(cards)
      |> apply_effects(effects)
      |> check_for_winner(player_index)
      |> advance_turn()
      |> update_timestamp()
      |> increment_turn_count()}
    else
      error -> error
    end
  end

  @doc """
  Executes a draw card action for the current player.
  After drawing from an attack, the player still gets their turn.
  """
  def draw_cards(%__MODULE__{} = game, player_id, reason \\ :cannot_play) do
    with {:ok, player_index} <- get_player_index(game, player_id),
         :ok <- validate_current_player(game, player_index) do
      
      draw_count = calculate_draw_count(game, reason)
      
      game = game
      |> draw_cards_from_deck(player_index, draw_count)
      |> clear_pending_attack(reason)
      |> update_timestamp()
      
      # If drawing due to attack, player still gets their turn
      # If drawing because cannot play, turn advances
      if reason == :attack do
        {:ok, game}  # Don't advance turn, player can still play
      else
        {:ok, game
        |> advance_turn()
        |> increment_turn_count()}
      end
    else
      error -> error
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

  defp validate_current_player(game, player_index) do
    if player_index == game.current_player_index do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp validate_cards_in_hand(game, player_index, cards) do
    player = Enum.at(game.players, player_index)
    if Enum.all?(cards, &(&1 in player.hand)) do
      :ok
    else
      {:error, :cards_not_in_hand}
    end
  end

  defp validate_play(game, cards) do
    cond do
      not Rules.valid_stack?(cards) ->
        {:error, :invalid_stack}
      
      game.pending_attack != nil ->
        validate_attack_response(game, cards)
      
      true ->
        validate_normal_play(game, cards)
    end
  end

  defp validate_attack_response(game, cards) do
    {attack_type, _} = game.pending_attack
    first_card = List.first(cards)
    
    if Rules.can_counter_attack?(first_card, attack_type) do
      :ok
    else
      {:error, :invalid_counter}
    end
  end

  defp validate_normal_play(game, cards) do
    first_card = List.first(cards)
    top = top_card(game)
    
    if Rules.can_play_card?(first_card, top, game.nominated_suit) do
      :ok
    else
      {:error, :invalid_play}
    end
  end

  defp calculate_and_validate_effects(cards, nominated_suit) do
    effects = Rules.calculate_effects(cards)
    
    # Add suit nomination if Aces were played
    effects = if Map.get(effects, :nominate_suit) && Rules.valid_suit?(nominated_suit) do
      Map.put(effects, :nominated_suit, nominated_suit)
    else
      effects
    end
    
    {:ok, effects}
  end

  defp remove_cards_from_hand(game, player_index, cards) do
    players = List.update_at(game.players, player_index, fn player ->
      new_hand = Enum.reject(player.hand, &(&1 in cards))
      Map.put(player, :hand, new_hand)
    end)
    
    %{game | players: players}
  end

  defp add_cards_to_discard(game, cards) do
    %{game | discard_pile: cards ++ game.discard_pile}
  end

  defp apply_effects(game, effects) do
    game
    |> apply_attack(Map.get(effects, :attack))
    |> apply_skip(Map.get(effects, :skip))
    |> apply_reverse(Map.get(effects, :reverse))
    |> apply_suit_nomination(Map.get(effects, :nominated_suit))
  end

  defp apply_attack(game, nil), do: game
  defp apply_attack(game, attack) do
    # Stack with existing attack if same type
    new_attack = case {game.pending_attack, attack} do
      {nil, attack} -> attack
      {{:twos, existing}, {:twos, new}} -> {:twos, existing + new}
      {{:black_jacks, existing}, {:black_jacks, new}} -> {:black_jacks, existing + new}
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

  defp check_for_winner(game, player_index) do
    player = Enum.at(game.players, player_index)
    
    if Enum.empty?(player.hand) do
      winners = game.winners ++ [player.id]
      players = List.update_at(game.players, player_index, &Map.put(&1, :status, :won))
      
      %{game | winners: winners, players: players}
    else
      game
    end
  end

  defp advance_turn(game) do
    # Clear suit nomination (only affects next player)
    game = %{game | nominated_suit: nil}
    
    # Calculate next player considering skips
    next_index = Rules.next_player_index(
      game.current_player_index,
      length(game.players),
      game.direction,
      game.pending_skips
    )
    
    %{game | 
      current_player_index: next_index,
      pending_skips: 0
    }
  end

  defp calculate_draw_count(_game, :cannot_play), do: 1
  defp calculate_draw_count(game, :attack) do
    case game.pending_attack do
      {:twos, count} -> count
      {:black_jacks, count} -> count
      _ -> 1
    end
  end

  defp draw_cards_from_deck(game, player_index, count) do
    {drawn, new_deck} = draw_with_reshuffle(game.deck, game.discard_pile, count)
    
    players = List.update_at(game.players, player_index, fn player ->
      Map.put(player, :hand, player.hand ++ drawn)
    end)
    
    %{game | players: players, deck: new_deck}
  end

  defp draw_with_reshuffle(deck, discard, count) do
    available = length(deck)
    
    if available >= count do
      Deck.draw(deck, count)
    else
      # Draw what we can from deck
      {first_batch, _} = if available > 0, do: Deck.draw(deck, available), else: {[], []}
      
      # Check if we can reshuffle (need more than just top card)
      if length(discard) > 1 do
        needed = count - available
        {_top_card, reshuffled} = Deck.reshuffle_discard(discard)
        
        # Draw remaining cards if possible
        cards_to_draw = min(needed, length(reshuffled))
        if cards_to_draw > 0 do
          {second_batch, final_deck} = Deck.draw(reshuffled, cards_to_draw)
          {first_batch ++ second_batch, final_deck}
        else
          {first_batch, reshuffled}
        end
      else
        # Can't reshuffle with only top card, return what we have
        {first_batch, []}
      end
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
end