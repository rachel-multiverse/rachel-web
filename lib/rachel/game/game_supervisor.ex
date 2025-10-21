defmodule Rachel.Game.GameSupervisor do
  @moduledoc """
  Supervisor for game server processes.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new game server with safety features.
  """
  def start_game(player_names, game_id \\ nil) do
    game_id = game_id || Ecto.UUID.generate()

    child_spec = %{
      id: game_id,
      start: {Rachel.Game.GameEngine, :start_link, [[players: player_names, game_id: game_id]]},
      # Restart if it crashes abnormally
      restart: :transient,
      max_restarts: 3
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, _pid} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  @doc """
  Stops a game server.
  """
  def stop_game(game_id) do
    case Registry.lookup(Rachel.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active game IDs.
  """
  def list_games do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(Rachel.GameRegistry, pid) do
        [game_id] -> game_id
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Restores a game from saved state (used on application restart).
  """
  def restore_game(game_state) do
    game_id = game_state.id

    child_spec = %{
      id: game_id,
      start: {Rachel.Game.GameEngine, :start_link, [[restore: game_state, game_id: game_id]]},
      restart: :transient,
      max_restarts: 3
    }

    # We need special init handling in GameEngine to accept {:restore, game_state}
    # Instead of the normal {players, game_id} tuple
    case DynamicSupervisor.start_child(__MODULE__, %{
           child_spec
           | start:
               {GenServer, :start_link,
                [Rachel.Game.GameEngine, {:restore, game_state}, [name: via(game_id)]]}
         }) do
      {:ok, _pid} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  defp via(game_id), do: {:via, Registry, {Rachel.GameRegistry, game_id}}
end
