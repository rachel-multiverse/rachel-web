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
  Starts a new game server.
  """
  def start_game(player_names, game_id \\ nil) do
    game_id = game_id || Ecto.UUID.generate()
    
    child_spec = %{
      id: game_id,
      start: {Rachel.Game.GameServer, :start_link, [[players: player_names, game_id: game_id]]},
      restart: :temporary
    }
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, _pid} -> {:ok, game_id}
      error -> error
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
end