defmodule Rachel.Game.ConnectionMonitor do
  @moduledoc """
  Monitors player connections and handles reconnection logic.
  Works with Phoenix LiveView to detect disconnections and reconnections.
  """

  use GenServer
  require Logger
  
  alias Rachel.Game.SessionManager

  @disconnect_grace_period_ms 10_000  # 10 seconds before marking as disconnected
  @reconnect_timeout_ms 30_000        # 30 seconds to reconnect before AI takeover

  defstruct monitors: %{}, timers: %{}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Starts monitoring a player's connection.
  Called when a player joins a game.
  """
  def monitor_player(session_token, socket_pid) do
    GenServer.call(__MODULE__, {:monitor, session_token, socket_pid})
  end

  @doc """
  Stops monitoring a player's connection.
  Called when a player leaves a game.
  """
  def unmonitor_player(session_token) do
    GenServer.cast(__MODULE__, {:unmonitor, session_token})
  end

  @doc """
  Called periodically by the LiveView to indicate the connection is alive.
  """
  def heartbeat(session_token) do
    GenServer.cast(__MODULE__, {:heartbeat, session_token})
  end

  @doc """
  Called when LiveView detects a disconnection.
  """
  def handle_disconnect(session_token) do
    GenServer.cast(__MODULE__, {:disconnected, session_token})
  end

  @doc """
  Called when a player reconnects.
  """
  def handle_reconnect(session_token, socket_pid) do
    GenServer.call(__MODULE__, {:reconnect, session_token, socket_pid})
  end

  # Server Callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_call({:monitor, session_token, socket_pid}, _from, state) do
    # Start monitoring the socket process
    ref = Process.monitor(socket_pid)
    
    monitor_info = %{
      session_token: session_token,
      socket_pid: socket_pid,
      monitor_ref: ref,
      status: :connected,
      last_heartbeat: System.monotonic_time(:millisecond)
    }
    
    new_monitors = Map.put(state.monitors, session_token, monitor_info)
    
    # Start heartbeat timer
    timer_ref = Process.send_after(self(), {:check_heartbeat, session_token}, @disconnect_grace_period_ms)
    new_timers = Map.put(state.timers, session_token, timer_ref)
    
    Logger.info("Started monitoring connection for session #{session_token}")
    
    {:reply, :ok, %{state | monitors: new_monitors, timers: new_timers}}
  end

  def handle_call({:reconnect, session_token, socket_pid}, _from, state) do
    case SessionManager.validate_session(session_token) do
      {:ok, session} ->
        # Cancel any pending disconnect/takeover timers
        state = cancel_timers(state, session_token)
        
        # Update monitor info
        ref = Process.monitor(socket_pid)
        
        monitor_info = %{
          session_token: session_token,
          socket_pid: socket_pid,
          monitor_ref: ref,
          status: :connected,
          last_heartbeat: System.monotonic_time(:millisecond)
        }
        
        new_monitors = Map.put(state.monitors, session_token, monitor_info)
        
        # Restart heartbeat timer
        timer_ref = Process.send_after(self(), {:check_heartbeat, session_token}, @disconnect_grace_period_ms)
        new_timers = Map.put(state.timers, session_token, timer_ref)
        
        # Update session status
        SessionManager.update_connection_status(session_token, :connected)
        
        Logger.info("Player reconnected: #{session.player_name} to game #{session.game_id}")
        
        {:reply, {:ok, session}, %{state | monitors: new_monitors, timers: new_timers}}
      
      error ->
        {:reply, error, state}
    end
  end

  def handle_cast({:unmonitor, session_token}, state) do
    case Map.get(state.monitors, session_token) do
      nil ->
        {:noreply, state}
      
      monitor_info ->
        # Stop monitoring
        Process.demonitor(monitor_info.monitor_ref, [:flush])
        
        # Cancel timers
        state = cancel_timers(state, session_token)
        
        # Remove from monitors
        new_monitors = Map.delete(state.monitors, session_token)
        
        {:noreply, %{state | monitors: new_monitors}}
    end
  end

  def handle_cast({:heartbeat, session_token}, state) do
    case Map.get(state.monitors, session_token) do
      nil ->
        {:noreply, state}
      
      monitor_info ->
        # Update last heartbeat
        updated_info = Map.put(monitor_info, :last_heartbeat, System.monotonic_time(:millisecond))
        new_monitors = Map.put(state.monitors, session_token, updated_info)
        
        {:noreply, %{state | monitors: new_monitors}}
    end
  end

  def handle_cast({:disconnected, session_token}, state) do
    case Map.get(state.monitors, session_token) do
      nil ->
        {:noreply, state}
      
      monitor_info ->
        # Mark as disconnected
        updated_info = Map.put(monitor_info, :status, :disconnected)
        new_monitors = Map.put(state.monitors, session_token, updated_info)
        
        # Cancel existing timer
        state = cancel_timers(state, session_token)
        
        # Start reconnect timeout timer
        timer_ref = Process.send_after(self(), {:reconnect_timeout, session_token}, @reconnect_timeout_ms)
        new_timers = Map.put(state.timers, session_token, timer_ref)
        
        # Update session status
        SessionManager.update_connection_status(session_token, :disconnected)
        
        Logger.info("Player disconnected, waiting for reconnect: #{session_token}")
        
        {:noreply, %{state | monitors: new_monitors, timers: new_timers}}
    end
  end

  def handle_info({:check_heartbeat, session_token}, state) do
    case Map.get(state.monitors, session_token) do
      nil ->
        {:noreply, state}
      
      monitor_info ->
        now = System.monotonic_time(:millisecond)
        time_since_heartbeat = now - monitor_info.last_heartbeat
        
        if time_since_heartbeat > @disconnect_grace_period_ms do
          # No heartbeat received, mark as disconnected
          handle_cast({:disconnected, session_token}, state)
        else
          # Schedule next check
          timer_ref = Process.send_after(self(), {:check_heartbeat, session_token}, @disconnect_grace_period_ms)
          new_timers = Map.put(state.timers, session_token, timer_ref)
          {:noreply, %{state | timers: new_timers}}
        end
    end
  end

  def handle_info({:reconnect_timeout, session_token}, state) do
    case SessionManager.validate_session(session_token) do
      {:ok, session} ->
        # Player didn't reconnect in time, handle AI takeover or pause
        Logger.warning("Reconnect timeout for player #{session.player_name} in game #{session.game_id}")
        
        # Notify game engine to handle player timeout
        handle_player_timeout(session)
        
        # Clean up monitoring
        new_monitors = Map.delete(state.monitors, session_token)
        new_timers = Map.delete(state.timers, session_token)
        
        {:noreply, %{state | monitors: new_monitors, timers: new_timers}}
      
      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find session token by socket pid
    case Enum.find(state.monitors, fn {_token, info} -> info.socket_pid == pid end) do
      nil ->
        {:noreply, state}
      
      {session_token, _monitor_info} ->
        # Socket process died, handle as disconnection
        handle_cast({:disconnected, session_token}, state)
    end
  end

  # Private Functions

  defp cancel_timers(state, session_token) do
    case Map.get(state.timers, session_token) do
      nil ->
        state
      
      timer_ref ->
        Process.cancel_timer(timer_ref)
        new_timers = Map.delete(state.timers, session_token)
        %{state | timers: new_timers}
    end
  end

  defp handle_player_timeout(session) do
    # Convert player to AI or pause game
    case Registry.lookup(Rachel.GameRegistry, session.game_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:player_timeout, session.player_id})
      
      [] ->
        Logger.error("Game not found for timeout: #{session.game_id}")
    end
  end
end