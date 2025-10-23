defmodule Rachel.Game.ConnectionMonitorTest do
  use ExUnit.Case, async: false

  alias Rachel.Game.ConnectionMonitor
  alias Rachel.Game.SessionManager

  setup do
    # ConnectionMonitor is already running as part of the application
    # Reset its state by replacing it with an empty state
    :sys.replace_state(ConnectionMonitor, fn _old -> %ConnectionMonitor{} end)

    # Also reset SessionManager for clean test state
    :sys.replace_state(SessionManager, fn _old -> %SessionManager{} end)

    :ok
  end

  describe "monitor_player/2" do
    test "starts monitoring a player with socket PID" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)

      Process.sleep(50)

      # Verify monitoring started by checking state
      state = :sys.get_state(ConnectionMonitor)
      assert Map.has_key?(state.monitors, token)
      assert state.monitors[token].socket_pid == socket_pid
      assert state.monitors[token].status == :connected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "tracks multiple players independently" do
      socket1 = spawn(fn -> Process.sleep(:infinity) end)
      socket2 = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, token2} = SessionManager.create_session("game-123", 1, "Bob")

      :ok = ConnectionMonitor.monitor_player(token1, socket1)
      :ok = ConnectionMonitor.monitor_player(token2, socket2)

      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      assert Map.has_key?(state.monitors, token1)
      assert Map.has_key?(state.monitors, token2)
      assert state.monitors[token1].socket_pid == socket1
      assert state.monitors[token2].socket_pid == socket2

      # Cleanup
      Process.exit(socket1, :kill)
      Process.exit(socket2, :kill)
    end

    test "initializes with current timestamp" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      before_time = System.monotonic_time(:millisecond)
      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)
      after_time = System.monotonic_time(:millisecond)

      state = :sys.get_state(ConnectionMonitor)
      monitor = state.monitors[token]

      assert monitor.last_heartbeat >= before_time
      assert monitor.last_heartbeat <= after_time

      # Cleanup
      Process.exit(socket_pid, :kill)
    end
  end

  describe "unmonitor_player/1" do
    test "stops monitoring a player" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      :ok = ConnectionMonitor.unmonitor_player(token)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      refute Map.has_key?(state.monitors, token)

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "cancels reconnect timer if active" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      # Simulate disconnect to start reconnect timer
      Process.exit(socket_pid, :kill)
      Process.sleep(100)

      # Unmonitor should cancel the timer
      :ok = ConnectionMonitor.unmonitor_player(token)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      refute Map.has_key?(state.monitors, token)
    end

    test "handles unmonitoring non-existent player gracefully" do
      # Should not crash
      :ok = ConnectionMonitor.unmonitor_player("nonexistent-token")
    end
  end

  describe "heartbeat/1" do
    test "updates last heartbeat timestamp" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      state1 = :sys.get_state(ConnectionMonitor)
      initial_heartbeat = state1.monitors[token].last_heartbeat

      Process.sleep(50)
      :ok = ConnectionMonitor.heartbeat(token)
      Process.sleep(50)

      state2 = :sys.get_state(ConnectionMonitor)
      updated_heartbeat = state2.monitors[token].last_heartbeat

      assert updated_heartbeat > initial_heartbeat

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "handles heartbeat for non-existent player gracefully" do
      # Should not crash
      :ok = ConnectionMonitor.heartbeat("nonexistent-token")
    end

    test "heartbeat does not change status" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      :ok = ConnectionMonitor.heartbeat(token)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      assert state.monitors[token].status == :connected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end
  end

  describe "handle_disconnect/1" do
    test "marks player as disconnected" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      assert state.monitors[token].status == :disconnected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "starts reconnect timeout timer" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      monitor = state.monitors[token]

      assert monitor.status == :disconnected
      # Timer is stored in separate timers map
      assert is_reference(state.timers[token])

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "updates SessionManager connection status" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(100)

      {:ok, session} = SessionManager.validate_session(token)
      assert session.status == :disconnected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "handles disconnect for non-existent player gracefully" do
      # Should not crash
      :ok = ConnectionMonitor.handle_disconnect("nonexistent-token")
    end
  end

  describe "handle_reconnect/2" do
    test "marks player as reconnected" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)
      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      new_socket = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _session} = ConnectionMonitor.handle_reconnect(token, new_socket)
      Process.sleep(50)

      state = :sys.get_state(ConnectionMonitor)
      monitor = state.monitors[token]

      assert monitor.status == :connected
      assert monitor.socket_pid == new_socket
      # Timers are in separate map, should be heartbeat timer not reconnect timer
      assert is_reference(state.timers[token])

      # Cleanup
      Process.exit(socket_pid, :kill)
      Process.exit(new_socket, :kill)
    end

    test "cancels reconnect timeout timer" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)
      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      state1 = :sys.get_state(ConnectionMonitor)
      old_timer = state1.timers[token]
      assert is_reference(old_timer)

      new_socket = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _session} = ConnectionMonitor.handle_reconnect(token, new_socket)
      Process.sleep(50)

      state2 = :sys.get_state(ConnectionMonitor)
      # Timer should be replaced with new heartbeat timer
      new_timer = state2.timers[token]
      assert is_reference(new_timer)
      assert old_timer != new_timer

      # Cleanup
      Process.exit(socket_pid, :kill)
      Process.exit(new_socket, :kill)
    end

    test "updates last heartbeat on reconnect" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)
      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      state1 = :sys.get_state(ConnectionMonitor)
      old_heartbeat = state1.monitors[token].last_heartbeat

      Process.sleep(50)
      new_socket = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _session} = ConnectionMonitor.handle_reconnect(token, new_socket)
      Process.sleep(50)

      state2 = :sys.get_state(ConnectionMonitor)
      new_heartbeat = state2.monitors[token].last_heartbeat

      assert new_heartbeat >= old_heartbeat

      # Cleanup
      Process.exit(socket_pid, :kill)
      Process.exit(new_socket, :kill)
    end

    test "handles reconnect for non-existent player gracefully" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)

      # Should return error for invalid session
      assert {:error, :invalid_session} =
               ConnectionMonitor.handle_reconnect("nonexistent-token", socket_pid)

      # Cleanup
      Process.exit(socket_pid, :kill)
    end
  end

  describe "check_heartbeat timer" do
    test "detects stale connections after 10 seconds" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      # Manually set last_heartbeat to 11 seconds ago (beyond 10s threshold)
      state = :sys.get_state(ConnectionMonitor)
      monitor = Map.get(state.monitors, token)
      stale_time = System.monotonic_time(:millisecond) - 11_000
      stale_monitor = Map.put(monitor, :last_heartbeat, stale_time)
      new_monitors = Map.put(state.monitors, token, stale_monitor)
      new_state = %{state | monitors: new_monitors}
      :sys.replace_state(ConnectionMonitor, fn _old -> new_state end)

      # Trigger heartbeat check with the specific token
      send(ConnectionMonitor, {:check_heartbeat, token})
      Process.sleep(100)

      # Should be marked as disconnected
      updated_state = :sys.get_state(ConnectionMonitor)
      assert updated_state.monitors[token].status == :disconnected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "keeps active connections unchanged" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      # Trigger heartbeat check with recent heartbeat
      send(ConnectionMonitor, {:check_heartbeat, token})
      Process.sleep(100)

      state = :sys.get_state(ConnectionMonitor)
      assert state.monitors[token].status == :connected

      # Cleanup
      Process.exit(socket_pid, :kill)
    end
  end

  describe "reconnect_timeout timer" do
    test "removes player after timeout expires" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)
      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(50)

      # Send the timeout message (no timer ref needed - checked in handle_info)
      send(ConnectionMonitor, {:reconnect_timeout, token})
      Process.sleep(100)

      # Player should be removed from monitoring
      updated_state = :sys.get_state(ConnectionMonitor)
      refute Map.has_key?(updated_state.monitors, token)

      # Cleanup
      Process.exit(socket_pid, :kill)
    end

    test "handles timeout for non-existent session" do
      # Send timeout for non-existent token - should not crash
      send(ConnectionMonitor, {:reconnect_timeout, "nonexistent-token"})
      Process.sleep(100)

      # Should not crash
      state = :sys.get_state(ConnectionMonitor)
      assert is_map(state.monitors)
    end
  end

  describe "process DOWN handling" do
    test "detects socket process crash" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      # Kill the socket process
      Process.exit(socket_pid, :kill)
      Process.sleep(150)

      # Should be marked as disconnected
      state = :sys.get_state(ConnectionMonitor)
      assert state.monitors[token].status == :disconnected
    end

    test "starts reconnect timer after socket crash" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      # Kill the socket process
      Process.exit(socket_pid, :kill)
      Process.sleep(150)

      state = :sys.get_state(ConnectionMonitor)
      # Timer stored in separate timers map
      assert is_reference(state.timers[token])
    end
  end

  describe "integration with SessionManager" do
    test "connection status syncs between systems" do
      socket_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # Start monitoring
      :ok = ConnectionMonitor.monitor_player(token, socket_pid)
      Process.sleep(50)

      {:ok, session1} = SessionManager.validate_session(token)
      assert session1.status == :connected

      # Disconnect
      :ok = ConnectionMonitor.handle_disconnect(token)
      Process.sleep(100)

      {:ok, session2} = SessionManager.validate_session(token)
      assert session2.status == :disconnected

      # Reconnect
      new_socket = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _session} = ConnectionMonitor.handle_reconnect(token, new_socket)
      Process.sleep(100)

      {:ok, session3} = SessionManager.validate_session(token)
      assert session3.status == :connected

      # Cleanup
      Process.exit(socket_pid, :kill)
      Process.exit(new_socket, :kill)
    end
  end
end
