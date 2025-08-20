defmodule Rachel.Game.GameEngine do
  @moduledoc """
  Consolidated game engine with safety features built-in.
  Replaces the scattered validation and duplicate functionality.
  """

  use GenServer
  require Logger

  alias Rachel.Game.{AIPlayer, GameState, Rules}

  defstruct [
    :game,
    :ai_turn_ref,
    :error_count,
    :last_checkpoint
  ]

  # Client API - Simple, clean interface

  def start_link(opts) do
    player_names = Keyword.fetch!(opts, :players)
    game_id = Keyword.get(opts, :game_id, Ecto.UUID.generate())
    GenServer.start_link(__MODULE__, {player_names, game_id}, name: via(game_id))
  end

  def get_state(game_id), do: call(game_id, :get_state)
  def start_game(game_id), do: call(game_id, :start_game)

  def play_cards(game_id, player_id, cards, suit \\ nil),
    do: call(game_id, {:play, player_id, cards, suit})

  def draw_cards(game_id, player_id, reason \\ :cannot_play),
    do: call(game_id, {:draw, player_id, reason})

  def add_player(game_id, name), do: call(game_id, {:join, name})
  def remove_player(game_id, player_id), do: call(game_id, {:leave, player_id})
  def subscribe(game_id), do: Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
  def unsubscribe(game_id), do: Phoenix.PubSub.unsubscribe(Rachel.PubSub, "game:#{game_id}")

  # Implementation

  def init({players, game_id}) do
    game = GameState.new(players) |> Map.put(:id, game_id)
    state = %__MODULE__{game: game, ai_turn_ref: nil, error_count: 0}
    {:ok, checkpoint(state)}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state.game}, state}
  end

  def handle_call(:start_game, _from, %{game: %{status: :waiting} = game} = state) do
    case safe_execute(game, &GameState.start_game/1) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game} |> schedule_ai() |> checkpoint()
        broadcast(new_game, :game_started)
        {:reply, {:ok, new_game}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:start_game, _from, %{game: %{status: status}} = state) do
    {:reply, {:error, {:invalid_status, status}}, state}
  end

  def handle_call({:play, player_id, cards, suit}, _from, state) do
    state = cancel_ai(state)

    case safe_play(state.game, player_id, cards, suit) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, error_count: 0} |> schedule_ai() |> checkpoint()
        broadcast(new_game, {:cards_played, player_id, cards})
        check_game_end(new_state)

      error ->
        {:reply, error, increment_errors(state)}
    end
  end

  def handle_call({:draw, player_id, reason}, _from, state) do
    state = cancel_ai(state)

    case safe_draw(state.game, player_id, reason) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, error_count: 0} |> schedule_ai() |> checkpoint()
        broadcast(new_game, {:cards_drawn, player_id, reason})
        {:reply, {:ok, new_game}, new_state}

      error ->
        {:reply, error, increment_errors(state)}
    end
  end

  def handle_call({:join, name}, _from, %{game: %{status: :waiting, players: players}} = state)
      when length(players) < 8 do
    player = %{
      id: Ecto.UUID.generate(),
      name: name,
      hand: [],
      type: :human,
      status: :playing
    }

    new_game = %{state.game | players: players ++ [player]}
    new_state = %{state | game: new_game} |> checkpoint()
    broadcast(new_game, {:player_joined, player})
    {:reply, {:ok, player.id}, new_state}
  end

  def handle_call({:join, _name}, _from, state) do
    {:reply, {:error, :cannot_join}, state}
  end

  def handle_call({:leave, _player_id}, _from, state) do
    # Implementation for player removal
    {:reply, :ok, state}
  end

  def handle_info(:ai_turn, %{game: game} = state) do
    case process_ai_turn(game) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game} |> schedule_ai() |> checkpoint()
        broadcast(new_game, :ai_played)
        {:noreply, check_game_end_noreply(new_state)}

      _ ->
        {:noreply, schedule_ai(state)}
    end
  end

  def handle_info(:cleanup, state) do
    {:stop, :normal, state}
  end

  # Consolidated Safety Functions

  defp safe_execute(game, operation) do
    try do
      result = operation.(game)

      if is_struct(result, GameState) do
        case validate_state(result) do
          :ok ->
            {:ok, result}

          error ->
            Logger.error("State validation failed: #{inspect(error)}")
            {:error, :invalid_state}
        end
      else
        {:ok, result}
      end
    rescue
      error ->
        Logger.error("Operation failed: #{inspect(error)}")
        {:error, :operation_failed}
    end
  end

  defp safe_play(game, player_id, cards, nominated_suit) do
    with {:ok, player_idx} <- find_player(game, player_id),
         :ok <- validate_turn(game, player_idx),
         :ok <- validate_cards(game, player_idx, cards),
         :ok <- validate_play_rules(game, cards) do
      safe_execute(game, fn g ->
        GameState.play_cards(g, player_id, cards, nominated_suit)
      end)
      |> case do
        {:ok, {:ok, new_game}} -> {:ok, new_game}
        {:ok, error} -> error
        error -> error
      end
    end
  end

  defp safe_draw(game, player_id, reason) do
    with {:ok, player_idx} <- find_player(game, player_id),
         :ok <- validate_turn(game, player_idx) do
      safe_execute(game, fn g ->
        GameState.draw_cards(g, player_id, reason)
      end)
      |> case do
        {:ok, {:ok, new_game}} -> {:ok, new_game}
        {:ok, error} -> error
        error -> error
      end
    end
  end

  # Validation (consolidated from multiple places)

  defp find_player(game, player_id) do
    case Enum.find_index(game.players, &(&1.id == player_id)) do
      nil -> {:error, :player_not_found}
      idx -> {:ok, idx}
    end
  end

  defp validate_turn(game, player_idx) do
    if player_idx == game.current_player_index do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp validate_cards(game, player_idx, cards) do
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
      game.pending_attack -> validate_counter(game, cards)
      true -> validate_normal(game, cards)
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

  defp validate_normal(game, cards) do
    case game.discard_pile do
      [] -> {:error, :no_discard_pile}
      [top | _] ->
        if Rules.can_play_card?(hd(cards), top, game.nominated_suit) do
          :ok
        else
          {:error, :invalid_play}
        end
    end
  end

  defp validate_state(%{status: :waiting}), do: :ok

  defp validate_state(game) do
    cards_in_hands = game.players |> Enum.flat_map(& &1.hand) |> length()
    total = cards_in_hands + length(game.deck) + length(game.discard_pile)

    if total == game.expected_total_cards do
      :ok
    else
      {:error, {:card_count, total}}
    end
  end

  # AI Management

  defp schedule_ai(%{game: %{status: :playing}} = state) do
    current = Enum.at(state.game.players, state.game.current_player_index)

    if current && current.type == :ai && current.status == :playing do
      delay = AIPlayer.thinking_delay(Map.get(current, :difficulty, :medium))
      ref = Process.send_after(self(), :ai_turn, delay)
      %{state | ai_turn_ref: ref}
    else
      state
    end
  end

  defp schedule_ai(state), do: state

  defp cancel_ai(%{ai_turn_ref: nil} = state), do: state

  defp cancel_ai(%{ai_turn_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | ai_turn_ref: nil}
  end

  defp process_ai_turn(game) do
    current = Enum.at(game.players, game.current_player_index)

    if current && current.type == :ai && current.status == :playing do
      try do
        case AIPlayer.choose_action(game, current, current.difficulty) do
          {:play, cards, suit} ->
            safe_play(game, current.id, cards, suit)

          {:draw, reason} ->
            safe_draw(game, current.id, reason)
        end
      rescue
        _ -> {:error, :ai_failed}
      end
    else
      {:error, :not_ai_turn}
    end
  end

  # Utilities

  defp check_game_end(%{game: game} = state) do
    if GameState.should_end?(game) do
      final_game = %{game | status: :finished}
      broadcast(final_game, :game_over)
      Process.send_after(self(), :cleanup, 5 * 60 * 1000)
      {:reply, {:ok, final_game}, %{state | game: final_game}}
    else
      {:reply, {:ok, game}, state}
    end
  end

  defp check_game_end_noreply(%{game: game} = state) do
    if GameState.should_end?(game) do
      final_game = %{game | status: :finished}
      broadcast(final_game, :game_over)
      Process.send_after(self(), :cleanup, 5 * 60 * 1000)
      %{state | game: final_game}
    else
      state
    end
  end

  defp checkpoint(state) do
    # Simple checkpoint - could save to persistence here
    %{state | last_checkpoint: System.system_time(:millisecond)}
  end

  defp increment_errors(%{error_count: count} = state) when count > 10 do
    Logger.error("Game #{state.game.id} has too many errors")
    %{state | game: %{state.game | status: :corrupted}}
  end

  defp increment_errors(state), do: %{state | error_count: state.error_count + 1}

  defp via(game_id), do: {:via, Registry, {Rachel.GameRegistry, game_id}}
  defp call(game_id, msg), do: GenServer.call(via(game_id), msg)

  defp broadcast(game, event),
    do: Phoenix.PubSub.broadcast(Rachel.PubSub, "game:#{game.id}", {event, game})
end
