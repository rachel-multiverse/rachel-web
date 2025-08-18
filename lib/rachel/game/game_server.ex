defmodule Rachel.Game.GameServer do
  @moduledoc """
  GenServer that manages the state of a single Rachel game.
  Handles all game actions and maintains game state.
  """

  use GenServer
  require Logger

  alias Rachel.Game.GameState

  # Client API

  @doc """
  Starts a new game server with the given players.
  """
  def start_link(opts) do
    player_names = Keyword.fetch!(opts, :players)
    game_id = Keyword.get(opts, :game_id, Ecto.UUID.generate())

    GenServer.start_link(__MODULE__, {player_names, game_id}, name: via_tuple(game_id))
  end

  @doc """
  Gets the current game state.
  """
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  @doc """
  Starts the game (deals cards, sets initial state).
  """
  def start_game(game_id) do
    GenServer.call(via_tuple(game_id), :start_game)
  end

  @doc """
  Player plays cards.
  """
  def play_cards(game_id, player_id, cards, nominated_suit \\ nil) do
    GenServer.call(via_tuple(game_id), {:play_cards, player_id, cards, nominated_suit})
  end

  @doc """
  Player draws cards.
  """
  def draw_cards(game_id, player_id, reason \\ :cannot_play) do
    GenServer.call(via_tuple(game_id), {:draw_cards, player_id, reason})
  end

  @doc """
  Adds a player to a waiting game.
  """
  def add_player(game_id, player_name) do
    GenServer.call(via_tuple(game_id), {:add_player, player_name})
  end

  @doc """
  Removes a player from the game.
  """
  def remove_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:remove_player, player_id})
  end

  @doc """
  Subscribes to game events.
  """
  def subscribe(game_id) do
    Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
  end

  @doc """
  Unsubscribes from game events.
  """
  def unsubscribe(game_id) do
    Phoenix.PubSub.unsubscribe(Rachel.PubSub, "game:#{game_id}")
  end

  # Server Callbacks

  @impl true
  def init({player_names, game_id}) do
    game = GameState.new(player_names)
    game_with_id = %{game | id: game_id}
    {:ok, game_with_id}
  end

  @impl true
  def handle_call(:get_state, _from, game) do
    {:reply, {:ok, game}, game}
  end

  @impl true
  def handle_call(:start_game, _from, game) do
    case game.status do
      :waiting ->
        new_game = GameState.start_game(game)
        broadcast_update(new_game, :game_started)
        {:reply, {:ok, new_game}, new_game}

      status ->
        {:reply, {:error, {:invalid_status, status}}, game}
    end
  end

  @impl true
  def handle_call({:play_cards, player_id, cards, nominated_suit}, _from, game) do
    case GameState.play_cards(game, player_id, cards, nominated_suit) do
      {:ok, new_game} ->
        broadcast_update(new_game, {:cards_played, player_id, cards})
        check_game_over(new_game)
        {:reply, {:ok, new_game}, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:draw_cards, player_id, reason}, _from, game) do
    case GameState.draw_cards(game, player_id, reason) do
      {:ok, new_game} ->
        broadcast_update(new_game, {:cards_drawn, player_id, reason})
        {:reply, {:ok, new_game}, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:add_player, player_name}, _from, game) do
    if game.status == :waiting and length(game.players) < 8 do
      new_player = %{
        id: Ecto.UUID.generate(),
        name: player_name,
        hand: [],
        type: :human,
        status: :playing
      }

      new_game = %{game | players: game.players ++ [new_player]}
      broadcast_update(new_game, {:player_joined, new_player})
      {:reply, {:ok, new_player.id}, new_game}
    else
      {:reply, {:error, :cannot_join}, game}
    end
  end

  @impl true
  def handle_call({:remove_player, player_id}, _from, game) do
    if game.status == :waiting do
      new_players = Enum.reject(game.players, &(&1.id == player_id))
      new_game = %{game | players: new_players}
      broadcast_update(new_game, {:player_left, player_id})
      {:reply, :ok, new_game}
    else
      # During game, mark player as disconnected instead of removing
      new_players =
        Enum.map(game.players, fn p ->
          if p.id == player_id do
            %{p | status: :disconnected}
          else
            p
          end
        end)

      new_game = %{game | players: new_players}
      broadcast_update(new_game, {:player_disconnected, player_id})
      {:reply, :ok, new_game}
    end
  end

  # Private Functions

  defp via_tuple(game_id) do
    {:via, Registry, {Rachel.GameRegistry, game_id}}
  end

  defp broadcast_update(game, event) do
    Phoenix.PubSub.broadcast(
      Rachel.PubSub,
      "game:#{game.id}",
      {event, game}
    )
  end

  defp check_game_over(game) do
    active_players = Enum.count(game.players, &(&1.status == :playing))

    if active_players <= 1 do
      new_game = %{game | status: :finished}
      broadcast_update(new_game, :game_over)

      # Schedule cleanup after 5 minutes
      Process.send_after(self(), :cleanup, 5 * 60 * 1000)
    end
  end

  @impl true
  def handle_info(:cleanup, game) do
    Logger.info("Cleaning up finished game #{game.id}")
    {:stop, :normal, game}
  end
end
