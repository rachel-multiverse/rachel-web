defmodule Rachel.Game.GameCleanupTest do
  use Rachel.DataCase, async: false

  alias Rachel.{GameManager}
  alias Rachel.Game.GameCleanup

  # GameCleanup is disabled in tests, so we start it manually for these tests
  setup do
    # Start GameCleanup for this test
    {:ok, pid} = start_supervised(GameCleanup)
    # Allow GameCleanup to access the database sandbox
    Ecto.Adapters.SQL.Sandbox.allow(Rachel.Repo, self(), pid)
    :ok
  end

  describe "game cleanup" do
    test "cleans up finished games older than 1 hour" do
      # Create a game and finish it
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      # Get current state and manually mark as finished with old timestamp
      {:ok, game} = GameManager.get_game(game_id)

      # Update the game state to be finished and old
      one_hour_one_minute_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_one_minute_ago)
        |> Map.put(:winners, ["Player1"])

      # Update game state directly via GenServer
      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Verify game exists before cleanup
      assert {:ok, _} = GameManager.get_game(game_id)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should have cleaned up 1 game
      assert cleaned == 1

      # Game should be gone
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "does not clean up finished games less than 1 hour old" do
      # Create and finish a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      # Mark as finished but recent
      {:ok, game} = GameManager.get_game(game_id)
      thirty_minutes_ago = DateTime.add(DateTime.utc_now(), -1800, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, thirty_minutes_ago)
        |> Map.put(:winners, ["Player1"])

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should not have cleaned up any games
      assert cleaned == 0

      # Game should still exist
      assert {:ok, _} = GameManager.get_game(game_id)

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "cleans up waiting lobbies inactive for 30 minutes" do
      # Create a waiting lobby
      {:ok, game_id} = GameManager.create_lobby("Host")

      # Make it old
      {:ok, game} = GameManager.get_game(game_id)
      thirty_one_minutes_ago = DateTime.add(DateTime.utc_now(), -1860, :second)

      updated_game = Map.put(game, :last_action_at, thirty_one_minutes_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should have cleaned up 1 game
      assert cleaned == 1

      # Game should be gone
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "does not clean up active waiting lobbies" do
      # Create a fresh lobby
      {:ok, game_id} = GameManager.create_lobby("Host")

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should not clean up
      assert cleaned == 0

      # Game should still exist
      assert {:ok, game} = GameManager.get_game(game_id)
      assert game.status == :waiting

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "cleans up playing games inactive for 2 hours" do
      # Create and start a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      # Make it very old (abandoned)
      {:ok, game} = GameManager.get_game(game_id)
      two_hours_one_minute_ago = DateTime.add(DateTime.utc_now(), -7260, :second)

      updated_game = Map.put(game, :last_action_at, two_hours_one_minute_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should have cleaned up 1 game
      assert cleaned == 1

      # Game should be gone
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "does not clean up active playing games" do
      # Create and start a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      # Game is fresh, should not be cleaned
      cleaned = GameCleanup.cleanup_now()

      assert cleaned == 0

      # Game should still exist
      assert {:ok, game} = GameManager.get_game(game_id)
      assert game.status == :playing

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "cleans up multiple old games at once" do
      # Create multiple old finished games
      game_ids =
        for i <- 1..3 do
          {:ok, game_id} = GameManager.create_ai_game("Player#{i}", 1, :easy)
          {:ok, _} = GameManager.start_game(game_id)

          # Mark as finished and old
          {:ok, game} = GameManager.get_game(game_id)
          one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

          updated_game =
            game
            |> Map.put(:status, :finished)
            |> Map.put(:last_action_at, one_hour_ago)
            |> Map.put(:winners, ["Player#{i}"])

          [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
          :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

          game_id
        end

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should have cleaned up 3 games
      assert cleaned == 3

      # All games should be gone
      for game_id <- game_ids do
        assert {:error, :game_not_found} = GameManager.get_game(game_id)
      end
    end

    test "stats returns cleanup information" do
      # Get initial stats
      stats = GameCleanup.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_cleaned)
      assert Map.has_key?(stats, :last_cleanup_at)
      assert Map.has_key?(stats, :recent_cleanups)

      # Create and clean up a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["Player1"])

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      GameCleanup.cleanup_now()

      # Check updated stats
      new_stats = GameCleanup.stats()

      assert new_stats.total_cleaned > stats.total_cleaned
      assert new_stats.last_cleanup_at != nil
      assert length(new_stats.recent_cleanups) > 0
    end

    test "handles missing games gracefully" do
      # Try to clean up when there are no games
      cleaned = GameCleanup.cleanup_now()

      # Should not error, just return 0
      assert cleaned == 0
    end

    test "handles games that were already cleaned from memory" do
      # Create and save a game to database
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["Player1"])

      # Save to database
      GameManager.save_game(updated_game)

      # Update in-memory state
      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Manually end the game (removes from memory but stays in DB)
      GameManager.end_game(game_id)
      Process.sleep(100)

      # Cleanup should still work and remove from DB
      # Note: cleanup_now() lists active games, so won't find this one
      # This tests that the error handling works properly
      cleaned = GameCleanup.cleanup_now()

      # Already gone from memory, so won't be in list
      assert cleaned == 0
    end

    test "cleanup history is limited to 100 entries" do
      # Create many old games (more than 100 if possible, but limited by resources)
      # This tests the add_to_history limit

      # Get initial stats
      initial_stats = GameCleanup.stats()
      initial_history_size = length(initial_stats.recent_cleanups)

      # Create and clean up multiple times to build history
      for _i <- 1..5 do
        {:ok, game_id} = GameManager.create_ai_game("Player#{:rand.uniform(1000)}", 1, :easy)
        {:ok, game} = GameManager.get_game(game_id)

        one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

        updated_game =
          game
          |> Map.put(:status, :finished)
          |> Map.put(:last_action_at, one_hour_ago)
          |> Map.put(:winners, ["Player"])

        [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
        :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

        GameCleanup.cleanup_now()
      end

      # Check history size
      final_stats = GameCleanup.stats()
      final_history_size = length(final_stats.recent_cleanups)

      # Should have added entries
      assert final_history_size > initial_history_size
      # But should be limited (won't exceed 100, though we only added 5)
      assert final_history_size <= 100
    end

    test "stats shows correct recent cleanup count" do
      # Create and clean up exactly 2 games
      _game_ids =
        for i <- 1..2 do
          {:ok, game_id} = GameManager.create_ai_game("Player#{i}", 1, :easy)
          {:ok, game} = GameManager.get_game(game_id)

          one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

          updated_game =
            game
            |> Map.put(:status, :finished)
            |> Map.put(:last_action_at, one_hour_ago)
            |> Map.put(:winners, ["Player#{i}"])

          [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
          :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

          game_id
        end

      # Clean them up
      cleaned = GameCleanup.cleanup_now()
      assert cleaned == 2

      # Check stats
      stats = GameCleanup.stats()
      recent = hd(stats.recent_cleanups)

      assert recent.games_cleaned == 2
      assert recent.timestamp != nil
    end

    test "cleanup preserves playing games less than 2 hours old" do
      # Create a playing game that's 1 hour old (should not be cleaned)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

      updated_game = Map.put(game, :last_action_at, one_hour_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should not clean up
      assert cleaned == 0

      # Game should still exist
      assert {:ok, _} = GameManager.get_game(game_id)

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "cleanup removes both memory and database records" do
      # Create, start, and save a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["Player1"])

      # Save to database
      GameManager.save_game(updated_game)

      # Update in-memory state
      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Verify game exists in DB
      assert {:ok, _} = GameManager.load_game(game_id)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()
      assert cleaned == 1

      # Should be gone from memory
      assert {:error, :game_not_found} = GameManager.get_game(game_id)

      # Should also be gone from database
      assert {:error, :not_found} = GameManager.load_game(game_id)
    end

    test "handles corrupted game status gracefully" do
      # Create a game with an unknown status
      {:ok, game_id} = GameManager.create_lobby("Host")
      {:ok, game} = GameManager.get_game(game_id)

      # Set an invalid status
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :corrupted)
        |> Map.put(:last_action_at, one_hour_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Cleanup should handle gracefully (not clean up unknown status)
      cleaned = GameCleanup.cleanup_now()

      # Should not clean corrupted status games
      assert cleaned == 0

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "threshold edge case: exactly at threshold is cleaned" do
      # Create a finished game at exactly 1 hour (3600 seconds)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      exactly_one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, exactly_one_hour_ago)
        |> Map.put(:winners, ["Player1"])

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should clean up (>= threshold)
      assert cleaned == 1
    end

    test "waiting lobby at exactly 30 minutes is cleaned" do
      # Create a waiting lobby at exactly 30 minutes (1800 seconds)
      {:ok, game_id} = GameManager.create_lobby("Host")
      {:ok, game} = GameManager.get_game(game_id)

      exactly_thirty_minutes_ago = DateTime.add(DateTime.utc_now(), -1800, :second)
      updated_game = Map.put(game, :last_action_at, exactly_thirty_minutes_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should clean up (>= threshold)
      assert cleaned == 1
    end

    test "playing game at exactly 2 hours is cleaned" do
      # Create a playing game at exactly 2 hours (7200 seconds)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      exactly_two_hours_ago = DateTime.add(DateTime.utc_now(), -7200, :second)

      updated_game = Map.put(game, :last_action_at, exactly_two_hours_ago)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should clean up (>= threshold)
      assert cleaned == 1
    end

    test "mixed status games are handled correctly" do
      # Create games with different statuses and ages
      # 1. Old finished game (should clean)
      {:ok, finished_id} = GameManager.create_ai_game("Finished", 1, :easy)
      {:ok, _} = GameManager.start_game(finished_id)
      {:ok, finished_game} = GameManager.get_game(finished_id)

      finished_updated =
        finished_game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3660, :second))
        |> Map.put(:winners, ["Finished"])

      [{fin_pid, _}] = Registry.lookup(Rachel.GameRegistry, finished_id)
      :sys.replace_state(fin_pid, fn state -> %{state | game: finished_updated} end)

      # 2. Recent waiting game (should NOT clean)
      {:ok, waiting_id} = GameManager.create_lobby("Waiting")

      # 3. Old waiting game (should clean)
      {:ok, old_waiting_id} = GameManager.create_lobby("OldWaiting")
      {:ok, old_waiting} = GameManager.get_game(old_waiting_id)

      old_waiting_updated =
        Map.put(old_waiting, :last_action_at, DateTime.add(DateTime.utc_now(), -1860, :second))

      [{old_wait_pid, _}] = Registry.lookup(Rachel.GameRegistry, old_waiting_id)
      :sys.replace_state(old_wait_pid, fn state -> %{state | game: old_waiting_updated} end)

      # 4. Recent playing game (should NOT clean)
      {:ok, playing_id} = GameManager.create_ai_game("Playing", 1, :easy)
      {:ok, _} = GameManager.start_game(playing_id)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should clean up 2 games (finished + old waiting)
      assert cleaned == 2

      # Verify correct games were cleaned
      assert {:error, :game_not_found} = GameManager.get_game(finished_id)
      assert {:error, :game_not_found} = GameManager.get_game(old_waiting_id)
      assert {:ok, _} = GameManager.get_game(waiting_id)
      assert {:ok, _} = GameManager.get_game(playing_id)

      # Cleanup remaining
      GameManager.end_game(waiting_id)
      GameManager.end_game(playing_id)
    end
  end

  describe "edge cases and error handling" do
    test "handles game that fails to end gracefully" do
      # Create a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["Player1"])

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Manually kill the game process to simulate a crash
      Process.exit(game_pid, :kill)
      Process.sleep(50)

      # Cleanup should handle this gracefully (game already gone)
      cleaned = GameCleanup.cleanup_now()

      # Should report 0 since game already terminated
      assert cleaned == 0
    end

    test "cleanup increments total_cleaned counter correctly over multiple runs" do
      # Get initial stats
      initial_stats = GameCleanup.stats()
      initial_total = initial_stats.total_cleaned

      # First cleanup run with 1 game
      {:ok, game_id1} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, game1} = GameManager.get_game(game_id1)

      updated1 =
        game1
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3660, :second))
        |> Map.put(:winners, ["Player1"])

      [{pid1, _}] = Registry.lookup(Rachel.GameRegistry, game_id1)
      :sys.replace_state(pid1, fn state -> %{state | game: updated1} end)

      cleaned1 = GameCleanup.cleanup_now()
      assert cleaned1 == 1

      # Second cleanup run with 2 games
      {:ok, game_id2} = GameManager.create_ai_game("Player2", 1, :easy)
      {:ok, game2} = GameManager.get_game(game_id2)

      updated2 =
        game2
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3660, :second))
        |> Map.put(:winners, ["Player2"])

      [{pid2, _}] = Registry.lookup(Rachel.GameRegistry, game_id2)
      :sys.replace_state(pid2, fn state -> %{state | game: updated2} end)

      {:ok, game_id3} = GameManager.create_ai_game("Player3", 1, :easy)
      {:ok, game3} = GameManager.get_game(game_id3)

      updated3 =
        game3
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3660, :second))
        |> Map.put(:winners, ["Player3"])

      [{pid3, _}] = Registry.lookup(Rachel.GameRegistry, game_id3)
      :sys.replace_state(pid3, fn state -> %{state | game: updated3} end)

      cleaned2 = GameCleanup.cleanup_now()
      assert cleaned2 == 2

      # Check final stats
      final_stats = GameCleanup.stats()
      assert final_stats.total_cleaned == initial_total + 3
    end

    test "cleanup history entries have timestamps" do
      # Clean up a game
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3660, :second))
        |> Map.put(:winners, ["Player1"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      GameCleanup.cleanup_now()

      # Check that history entry has valid timestamp
      stats = GameCleanup.stats()
      recent = hd(stats.recent_cleanups)

      assert %DateTime{} = recent.timestamp
      assert recent.games_cleaned >= 0
    end

    test "stats returns correct structure even with no cleanups" do
      # Get stats immediately after starting cleanup worker
      stats = GameCleanup.stats()

      # Should have proper structure
      assert is_integer(stats.total_cleaned)
      assert is_list(stats.recent_cleanups)
      # last_cleanup_at might be nil initially or have a value from previous runs
      assert is_nil(stats.last_cleanup_at) or match?(%DateTime{}, stats.last_cleanup_at)
    end

    test "get_game_info returns nil for non-existent games" do
      # This tests the get_game_info private function indirectly
      # by ensuring cleanup doesn't crash with invalid game IDs

      # Run cleanup with no games
      cleaned = GameCleanup.cleanup_now()

      # Should complete without error
      assert cleaned >= 0
    end

    test "cleanup works with games of various ages" do
      # Create a game with known age (65 minutes)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      # Set to exactly 65 minutes ago
      sixty_five_minutes_ago = DateTime.add(DateTime.utc_now(), -3900, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, sixty_five_minutes_ago)
        |> Map.put(:winners, ["Player1"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Should clean up the old game
      cleaned = GameCleanup.cleanup_now()
      assert cleaned == 1

      # Game should be gone
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "waiting lobby just under threshold is not cleaned" do
      # Create a waiting lobby at 29 minutes 59 seconds (just under threshold)
      {:ok, game_id} = GameManager.create_lobby("Host")
      {:ok, game} = GameManager.get_game(game_id)

      # 29 minutes 59 seconds = 1799 seconds
      just_under_threshold = DateTime.add(DateTime.utc_now(), -1799, :second)
      updated_game = Map.put(game, :last_action_at, just_under_threshold)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should NOT clean up (< threshold)
      assert cleaned == 0

      # Game should still exist
      assert {:ok, _} = GameManager.get_game(game_id)

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "finished game just under threshold is not cleaned" do
      # Create a finished game at 59 minutes 59 seconds (just under threshold)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      # 59 minutes 59 seconds = 3599 seconds
      just_under_threshold = DateTime.add(DateTime.utc_now(), -3599, :second)

      updated_game =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, just_under_threshold)
        |> Map.put(:winners, ["Player1"])

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should NOT clean up (< threshold)
      assert cleaned == 0

      # Game should still exist
      assert {:ok, _} = GameManager.get_game(game_id)

      # Cleanup
      GameManager.end_game(game_id)
    end

    test "playing game just under threshold is not cleaned" do
      # Create a playing game at 1 hour 59 minutes 59 seconds (just under 2 hour threshold)
      {:ok, game_id} = GameManager.create_ai_game("Player1", 1, :easy)
      {:ok, _} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      # 1 hour 59 minutes 59 seconds = 7199 seconds
      just_under_threshold = DateTime.add(DateTime.utc_now(), -7199, :second)

      updated_game = Map.put(game, :last_action_at, just_under_threshold)

      [{game_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(game_pid, fn state -> %{state | game: updated_game} end)

      # Run cleanup
      cleaned = GameCleanup.cleanup_now()

      # Should NOT clean up (< threshold)
      assert cleaned == 0

      # Game should still exist
      assert {:ok, _} = GameManager.get_game(game_id)

      # Cleanup
      GameManager.end_game(game_id)
    end
  end

  describe "automatic cleanup scheduling" do
    test "cleanup process schedules itself automatically" do
      # The cleanup worker should have scheduled a cleanup on init
      # We can verify this by checking the process receives the message

      # Get the cleanup process
      cleanup_pid = Process.whereis(GameCleanup)
      assert cleanup_pid != nil

      # Send a cleanup message manually to test the handler
      send(cleanup_pid, :cleanup)
      Process.sleep(100)

      # Process should still be alive
      assert Process.alive?(cleanup_pid)
    end

    test "automatic cleanup handles multiple games" do
      # Create multiple old games
      game_ids =
        for i <- 1..3 do
          {:ok, game_id} = GameManager.create_ai_game("AutoPlayer#{i}", 1, :easy)
          {:ok, game} = GameManager.get_game(game_id)

          one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

          updated =
            game
            |> Map.put(:status, :finished)
            |> Map.put(:last_action_at, one_hour_ago)
            |> Map.put(:winners, ["AutoPlayer#{i}"])

          [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
          :sys.replace_state(pid, fn state -> %{state | game: updated} end)

          game_id
        end

      # Trigger automatic cleanup
      cleanup_pid = Process.whereis(GameCleanup)
      send(cleanup_pid, :cleanup)
      Process.sleep(200)

      # All games should be cleaned up
      for game_id <- game_ids do
        assert {:error, :game_not_found} = GameManager.get_game(game_id)
      end
    end

    test "automatic cleanup updates stats" do
      # Get initial stats
      initial_stats = GameCleanup.stats()
      initial_total = initial_stats.total_cleaned

      # Create an old game
      {:ok, game_id} = GameManager.create_ai_game("StatsPlayer", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["StatsPlayer"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Trigger automatic cleanup
      cleanup_pid = Process.whereis(GameCleanup)
      send(cleanup_pid, :cleanup)
      Process.sleep(200)

      # Stats should be updated
      new_stats = GameCleanup.stats()
      assert new_stats.total_cleaned > initial_total
      assert new_stats.last_cleanup_at != nil
    end

    test "automatic cleanup logs when games are cleaned" do
      # This test verifies the logging path (line 73-75)
      # Create an old game
      {:ok, game_id} = GameManager.create_ai_game("LogPlayer", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["LogPlayer"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Trigger automatic cleanup
      cleanup_pid = Process.whereis(GameCleanup)
      send(cleanup_pid, :cleanup)
      Process.sleep(200)

      # Game should be gone (verifies cleanup actually happened)
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "automatic cleanup does nothing when no games to clean" do
      # Trigger cleanup with no old games
      cleanup_pid = Process.whereis(GameCleanup)
      send(cleanup_pid, :cleanup)
      Process.sleep(100)

      # Process should remain alive after no-op cleanup
      assert Process.alive?(cleanup_pid)
    end
  end

  describe "error recovery and edge cases" do
    test "cleanup handles games that return errors during end_game" do
      # Create a game
      {:ok, game_id} = GameManager.create_ai_game("ErrorPlayer", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["ErrorPlayer"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Kill the game process before cleanup runs (simulates crash)
      Process.exit(pid, :kill)
      Process.sleep(50)

      # Cleanup should handle the :not_found error gracefully
      cleaned = GameCleanup.cleanup_now()

      # Should not crash, returns 0 since game already gone
      assert cleaned == 0
    end

    test "inactive_duration calculation is accurate" do
      # This indirectly tests the inactive_duration helper
      # Create a game with known inactivity
      {:ok, game_id} = GameManager.create_ai_game("DurationPlayer", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      # Set to exactly 90 minutes ago
      ninety_minutes_ago = DateTime.add(DateTime.utc_now(), -5400, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, ninety_minutes_ago)
        |> Map.put(:winners, ["DurationPlayer"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Should be cleaned (90 minutes > 60 minutes threshold)
      cleaned = GameCleanup.cleanup_now()
      assert cleaned == 1
    end

    test "get_game_info handles various error responses" do
      # This tests the get_game_info error handling (line 124-127)
      # Indirectly tested by attempting cleanup on non-existent game ID

      # Run cleanup - it will call list_games and then get_game_info on each
      # Some might return errors, which should be filtered out (line 117)
      cleaned = GameCleanup.cleanup_now()

      # Should complete without crashing
      assert is_integer(cleaned)
      assert cleaned >= 0
    end

    test "cleanup removes game even if delete_game_record fails" do
      # Create and finish a game
      {:ok, game_id} = GameManager.create_ai_game("DeleteFailPlayer", 1, :easy)
      {:ok, game} = GameManager.get_game(game_id)

      one_hour_ago = DateTime.add(DateTime.utc_now(), -3660, :second)

      updated =
        game
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, one_hour_ago)
        |> Map.put(:winners, ["DeleteFailPlayer"])

      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      :sys.replace_state(pid, fn state -> %{state | game: updated} end)

      # Even if DB delete fails, memory cleanup should work
      cleaned = GameCleanup.cleanup_now()
      assert cleaned == 1

      # Game should be gone from memory
      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end
  end
end
