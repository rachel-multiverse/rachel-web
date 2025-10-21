defmodule Rachel.Game.GameCleanupTest do
  use ExUnit.Case, async: false

  alias Rachel.{GameManager}
  alias Rachel.Game.GameCleanup

  # GameCleanup is already started by the application supervisor
  # No need to start it in setup

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
  end
end
