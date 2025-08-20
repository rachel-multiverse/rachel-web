defmodule Rachel.Game.SessionManager do
  @moduledoc """
  Manages player sessions for reconnection support.
  Tracks active connections and handles disconnection/reconnection gracefully.
  """

  use GenServer
  require Logger

  @session_timeout_ms 5 * 60 * 1000  # 5 minutes before session expires
  @cleanup_interval_ms 60 * 1000     # Clean up expired sessions every minute

  defstruct sessions: %{}, game_players: %{}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Creates or updates a session for a player.
  Returns a session token that can be used for reconnection.
  """
  def create_session(game_id, player_id, player_name) do
    GenServer.call(__MODULE__, {:create_session, game_id, player_id, player_name})
  end

  @doc """
  Validates a session token and returns the associated game and player info.
  """
  def validate_session(session_token) do
    GenServer.call(__MODULE__, {:validate_session, session_token})
  end

  @doc """
  Marks a player as connected/disconnected.
  """
  def update_connection_status(session_token, status) when status in [:connected, :disconnected] do
    GenServer.cast(__MODULE__, {:update_status, session_token, status})
  end

  @doc """
  Gets all sessions for a game.
  """
  def get_game_sessions(game_id) do
    GenServer.call(__MODULE__, {:get_game_sessions, game_id})
  end

  @doc """
  Removes a session (when player explicitly leaves).
  """
  def remove_session(session_token) do
    GenServer.cast(__MODULE__, {:remove_session, session_token})
  end

  # Server Callbacks

  def init(state) do
    # Schedule periodic cleanup of expired sessions
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
    {:ok, state}
  end

  def handle_call({:create_session, game_id, player_id, player_name}, _from, state) do
    session_token = generate_session_token()
    
    session = %{
      token: session_token,
      game_id: game_id,
      player_id: player_id,
      player_name: player_name,
      status: :connected,
      created_at: System.monotonic_time(:millisecond),
      last_activity: System.monotonic_time(:millisecond)
    }
    
    new_sessions = Map.put(state.sessions, session_token, session)
    
    # Track which players belong to which games
    game_players = Map.update(
      state.game_players,
      game_id,
      MapSet.new([player_id]),
      &MapSet.put(&1, player_id)
    )
    
    new_state = %{state | sessions: new_sessions, game_players: game_players}
    
    Logger.info("Session created for player #{player_name} in game #{game_id}")
    
    {:reply, {:ok, session_token}, new_state}
  end

  def handle_call({:validate_session, session_token}, _from, state) do
    case Map.get(state.sessions, session_token) do
      nil ->
        {:reply, {:error, :invalid_session}, state}
      
      session ->
        # Check if session is expired
        now = System.monotonic_time(:millisecond)
        if now - session.last_activity > @session_timeout_ms do
          {:reply, {:error, :session_expired}, state}
        else
          # Update last activity
          updated_session = Map.put(session, :last_activity, now)
          new_sessions = Map.put(state.sessions, session_token, updated_session)
          new_state = %{state | sessions: new_sessions}
          
          {:reply, {:ok, session}, new_state}
        end
    end
  end

  def handle_call({:get_game_sessions, game_id}, _from, state) do
    game_sessions = 
      state.sessions
      |> Map.values()
      |> Enum.filter(&(&1.game_id == game_id))
      |> Enum.map(fn session ->
        %{
          player_id: session.player_id,
          player_name: session.player_name,
          status: session.status,
          last_activity: session.last_activity
        }
      end)
    
    {:reply, game_sessions, state}
  end

  def handle_cast({:update_status, session_token, status}, state) do
    case Map.get(state.sessions, session_token) do
      nil ->
        {:noreply, state}
      
      session ->
        updated_session = 
          session
          |> Map.put(:status, status)
          |> Map.put(:last_activity, System.monotonic_time(:millisecond))
        
        new_sessions = Map.put(state.sessions, session_token, updated_session)
        new_state = %{state | sessions: new_sessions}
        
        # Notify the game about the status change
        notify_game_about_status(updated_session)
        
        {:noreply, new_state}
    end
  end

  def handle_cast({:remove_session, session_token}, state) do
    case Map.get(state.sessions, session_token) do
      nil ->
        {:noreply, state}
      
      session ->
        new_sessions = Map.delete(state.sessions, session_token)
        
        # Clean up game_players tracking
        game_players = 
          case Map.get(state.game_players, session.game_id) do
            nil -> state.game_players
            players ->
              updated = MapSet.delete(players, session.player_id)
              if MapSet.size(updated) == 0 do
                Map.delete(state.game_players, session.game_id)
              else
                Map.put(state.game_players, session.game_id, updated)
              end
          end
        
        new_state = %{state | sessions: new_sessions, game_players: game_players}
        {:noreply, new_state}
    end
  end

  def handle_info(:cleanup_expired, state) do
    now = System.monotonic_time(:millisecond)
    
    {active_sessions, expired_sessions} = 
      state.sessions
      |> Map.split_with(fn {_token, session} ->
        now - session.last_activity <= @session_timeout_ms
      end)
    
    # Log expired sessions
    Enum.each(expired_sessions, fn {_token, session} ->
      Logger.info("Session expired for player #{session.player_name} in game #{session.game_id}")
    end)
    
    # Clean up game_players for expired sessions
    game_players = 
      Enum.reduce(expired_sessions, state.game_players, fn {_token, session}, acc ->
        case Map.get(acc, session.game_id) do
          nil -> acc
          players ->
            updated = MapSet.delete(players, session.player_id)
            if MapSet.size(updated) == 0 do
              Map.delete(acc, session.game_id)
            else
              Map.put(acc, session.game_id, updated)
            end
        end
      end)
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
    
    {:noreply, %{state | sessions: active_sessions, game_players: game_players}}
  end

  # Private Functions

  defp generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp notify_game_about_status(session) do
    # Broadcast player status to the game channel
    Phoenix.PubSub.broadcast(
      Rachel.PubSub,
      "game:#{session.game_id}",
      {:player_status, session.player_id, session.status}
    )
  end
end