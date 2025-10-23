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

  @type player_spec ::
          String.t()
          | {:user, integer(), String.t()}
          | {:anonymous, String.t()}
          | {:ai, String.t(), atom()}

  @doc """
  Starts a new game server with safety features.
  """
  @spec start_game([player_spec()], String.t() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def start_game(player_names, game_id \\ nil) do
    game_id = game_id || Ecto.UUID.generate()

    # Use simple {module, args} format that DynamicSupervisor expects
    case DynamicSupervisor.start_child(
           __MODULE__,
           {Rachel.Game.GameEngine, [players: player_names, game_id: game_id]}
         ) do
      {:ok, _pid} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  @doc """
  Stops a game server.
  """
  @spec stop_game(String.t()) :: :ok | {:error, :not_found}
  def stop_game(game_id) do
    case Registry.lookup(Rachel.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active game IDs.
  """
  @spec list_games() :: [String.t()]
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
  @spec restore_game(Rachel.Game.GameState.t()) ::
          {:ok, String.t()} | {:error, term()}
  def restore_game(game_state) do
    game_id = game_state.id

    # Use simple {module, args} format with restore option
    case DynamicSupervisor.start_child(
           __MODULE__,
           {Rachel.Game.GameEngine, [restore: game_state, game_id: game_id]}
         ) do
      {:ok, _pid} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  defp via(game_id), do: {:via, Registry, {Rachel.GameRegistry, game_id}}
end
