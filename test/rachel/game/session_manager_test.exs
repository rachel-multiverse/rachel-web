defmodule Rachel.Game.SessionManagerTest do
  use ExUnit.Case, async: false

  alias Rachel.Game.SessionManager

  setup do
    # SessionManager is already running as part of the application
    # Reset its state by replacing it with an empty state
    :sys.replace_state(SessionManager, fn _old -> %SessionManager{} end)

    :ok
  end

  describe "create_session/3" do
    test "creates a new session and returns a token" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "creates unique tokens for different sessions" do
      {:ok, token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, token2} = SessionManager.create_session("game-123", 1, "Bob")

      assert token1 != token2
    end

    test "tracks multiple sessions for the same game" do
      {:ok, _token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, _token2} = SessionManager.create_session("game-123", 1, "Bob")

      sessions = SessionManager.get_game_sessions("game-123")

      assert length(sessions) == 2
      assert Enum.any?(sessions, &(&1.player_name == "Alice"))
      assert Enum.any?(sessions, &(&1.player_name == "Bob"))
    end

    test "allows same player to have sessions in different games" do
      {:ok, token1} = SessionManager.create_session("game-1", 0, "Alice")
      {:ok, token2} = SessionManager.create_session("game-2", 0, "Alice")

      {:ok, session1} = SessionManager.validate_session(token1)
      {:ok, session2} = SessionManager.validate_session(token2)

      assert session1.game_id == "game-1"
      assert session2.game_id == "game-2"
    end
  end

  describe "validate_session/1" do
    test "validates a valid session token" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      assert {:ok, session} = SessionManager.validate_session(token)
      assert session.game_id == "game-123"
      assert session.player_id == 0
      assert session.player_name == "Alice"
      assert session.status == :connected
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_session} = SessionManager.validate_session("invalid-token")
    end

    test "updates last_activity on validation" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      {:ok, session1} = SessionManager.validate_session(token)
      Process.sleep(50)
      {:ok, session2} = SessionManager.validate_session(token)

      assert session2.last_activity >= session1.last_activity
    end

    test "returns error for expired session" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # Manually set last_activity to 6 minutes ago (beyond 5 minute timeout)
      state = :sys.get_state(SessionManager)
      session = Map.get(state.sessions, token)
      expired_time = System.monotonic_time(:millisecond) - (6 * 60 * 1000)
      expired_session = Map.put(session, :last_activity, expired_time)
      new_sessions = Map.put(state.sessions, token, expired_session)
      new_state = %{state | sessions: new_sessions}
      :sys.replace_state(SessionManager, fn _old -> new_state end)

      assert {:error, :session_expired} = SessionManager.validate_session(token)
    end
  end

  describe "update_connection_status/2" do
    test "updates status to disconnected" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = SessionManager.update_connection_status(token, :disconnected)

      # Give cast time to process
      Process.sleep(50)

      {:ok, session} = SessionManager.validate_session(token)
      assert session.status == :disconnected
    end

    test "updates status to connected" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = SessionManager.update_connection_status(token, :disconnected)
      Process.sleep(50)
      :ok = SessionManager.update_connection_status(token, :connected)
      Process.sleep(50)

      {:ok, session} = SessionManager.validate_session(token)
      assert session.status == :connected
    end

    test "handles invalid token gracefully" do
      # Should not crash
      :ok = SessionManager.update_connection_status("invalid-token", :disconnected)
    end

    test "updates last_activity when changing status" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      {:ok, session1} = SessionManager.validate_session(token)
      Process.sleep(10)
      :ok = SessionManager.update_connection_status(token, :disconnected)
      Process.sleep(50)
      {:ok, session2} = SessionManager.validate_session(token)

      assert session2.last_activity > session1.last_activity
    end
  end

  describe "get_game_sessions/1" do
    test "returns empty list for game with no sessions" do
      sessions = SessionManager.get_game_sessions("nonexistent-game")

      assert sessions == []
    end

    test "returns all sessions for a specific game" do
      {:ok, _token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, _token2} = SessionManager.create_session("game-123", 1, "Bob")
      {:ok, _token3} = SessionManager.create_session("game-456", 0, "Charlie")

      sessions = SessionManager.get_game_sessions("game-123")

      assert length(sessions) == 2
      assert Enum.any?(sessions, &(&1.player_name == "Alice"))
      assert Enum.any?(sessions, &(&1.player_name == "Bob"))
      refute Enum.any?(sessions, &(&1.player_name == "Charlie"))
    end

    test "includes player status in session info" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")
      :ok = SessionManager.update_connection_status(token, :disconnected)
      Process.sleep(50)

      sessions = SessionManager.get_game_sessions("game-123")

      alice_session = Enum.find(sessions, &(&1.player_name == "Alice"))
      assert alice_session.status == :disconnected
    end
  end

  describe "remove_session/1" do
    test "removes a session" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = SessionManager.remove_session(token)
      Process.sleep(50)

      assert {:error, :invalid_session} = SessionManager.validate_session(token)
    end

    test "removes session from game_sessions list" do
      {:ok, token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, _token2} = SessionManager.create_session("game-123", 1, "Bob")

      :ok = SessionManager.remove_session(token1)
      Process.sleep(50)

      sessions = SessionManager.get_game_sessions("game-123")

      assert length(sessions) == 1
      refute Enum.any?(sessions, &(&1.player_name == "Alice"))
    end

    test "handles invalid token gracefully" do
      # Should not crash
      :ok = SessionManager.remove_session("invalid-token")
    end

    test "cleans up game_players when last player removed" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      :ok = SessionManager.remove_session(token)
      Process.sleep(50)

      sessions = SessionManager.get_game_sessions("game-123")
      assert sessions == []
    end
  end

  describe "cleanup_expired sessions" do
    test "removes sessions that exceed timeout" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # Manually set last_activity to 6 minutes ago
      state = :sys.get_state(SessionManager)
      session = Map.get(state.sessions, token)
      expired_time = System.monotonic_time(:millisecond) - (6 * 60 * 1000)
      expired_session = Map.put(session, :last_activity, expired_time)
      new_sessions = Map.put(state.sessions, token, expired_session)
      new_state = %{state | sessions: new_sessions}
      :sys.replace_state(SessionManager, fn _old -> new_state end)

      # Trigger cleanup manually
      send(SessionManager, :cleanup_expired)
      Process.sleep(100)

      # Session should be removed
      sessions = SessionManager.get_game_sessions("game-123")
      assert sessions == []
    end

    test "keeps active sessions during cleanup" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # Trigger cleanup
      send(SessionManager, :cleanup_expired)
      Process.sleep(100)

      # Session should still exist
      {:ok, _session} = SessionManager.validate_session(token)
    end

    test "cleans up game_players for expired sessions" do
      {:ok, token1} = SessionManager.create_session("game-123", 0, "Alice")
      {:ok, _token2} = SessionManager.create_session("game-123", 1, "Bob")

      # Expire Alice's session
      state = :sys.get_state(SessionManager)
      session = Map.get(state.sessions, token1)
      expired_time = System.monotonic_time(:millisecond) - (6 * 60 * 1000)
      expired_session = Map.put(session, :last_activity, expired_time)
      new_sessions = Map.put(state.sessions, token1, expired_session)
      new_state = %{state | sessions: new_sessions}
      :sys.replace_state(SessionManager, fn _old -> new_state end)

      # Trigger cleanup
      send(SessionManager, :cleanup_expired)
      Process.sleep(100)

      # Bob's session should remain
      sessions = SessionManager.get_game_sessions("game-123")
      assert length(sessions) == 1
      assert hd(sessions).player_name == "Bob"
    end
  end

  describe "session token generation" do
    test "generates URL-safe tokens" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # Should not contain characters that need URL encoding
      assert token =~ ~r/^[A-Za-z0-9_-]+$/
    end

    test "generates tokens of sufficient length" do
      {:ok, token} = SessionManager.create_session("game-123", 0, "Alice")

      # 32 bytes base64 encoded should be ~43 characters
      assert String.length(token) >= 40
    end
  end
end
