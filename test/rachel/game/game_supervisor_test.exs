defmodule Rachel.Game.GameSupervisorTest do
  use Rachel.DataCase, async: false

  alias Rachel.Game.GameSupervisor
  alias Rachel.GameManager

  describe "start_game/2" do
    test "starts a new game with default generated ID" do
      assert {:ok, game_id} = GameSupervisor.start_game(["Player1", "Player2"])
      assert is_binary(game_id)

      # Game should be in the registry
      assert [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)

      # Cleanup
      GameSupervisor.stop_game(game_id)
    end

    test "starts a new game with provided ID" do
      custom_id = "custom-game-id-123"
      assert {:ok, ^custom_id} = GameSupervisor.start_game(["Player1"], custom_id)

      # Game should be registered with custom ID
      assert [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, custom_id)

      # Cleanup
      GameSupervisor.stop_game(custom_id)
    end

    test "returns error when starting game with duplicate ID" do
      custom_id = "duplicate-id"
      assert {:ok, ^custom_id} = GameSupervisor.start_game(["Player1"], custom_id)

      # Try to start another game with same ID
      assert {:error, {:already_started, _pid}} =
               GameSupervisor.start_game(["Player2"], custom_id)

      # Cleanup
      GameSupervisor.stop_game(custom_id)
    end

    test "starts multiple games with different IDs" do
      assert {:ok, game_id1} = GameSupervisor.start_game(["Player1"])
      assert {:ok, game_id2} = GameSupervisor.start_game(["Player2"])
      assert {:ok, game_id3} = GameSupervisor.start_game(["Player3"])

      assert game_id1 != game_id2
      assert game_id2 != game_id3
      assert game_id1 != game_id3

      # All games should be registered
      assert [{_, _}] = Registry.lookup(Rachel.GameRegistry, game_id1)
      assert [{_, _}] = Registry.lookup(Rachel.GameRegistry, game_id2)
      assert [{_, _}] = Registry.lookup(Rachel.GameRegistry, game_id3)

      # Cleanup
      GameSupervisor.stop_game(game_id1)
      GameSupervisor.stop_game(game_id2)
      GameSupervisor.stop_game(game_id3)
    end
  end

  describe "stop_game/1" do
    test "stops an existing game" do
      {:ok, game_id} = GameSupervisor.start_game(["Player1"])

      # Verify game exists
      assert [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)

      # Stop the game
      assert :ok = GameSupervisor.stop_game(game_id)

      # Wait for process to fully terminate
      Process.sleep(50)

      # Game should be gone from registry
      assert [] = Registry.lookup(Rachel.GameRegistry, game_id)
    end

    test "returns error when stopping non-existent game" do
      assert {:error, :not_found} = GameSupervisor.stop_game("non-existent-id")
    end

    test "stopping already stopped game returns error" do
      {:ok, game_id} = GameSupervisor.start_game(["Player1"])

      # Stop once
      assert :ok = GameSupervisor.stop_game(game_id)

      # Try to stop again
      assert {:error, :not_found} = GameSupervisor.stop_game(game_id)
    end
  end

  describe "list_games/0" do
    test "returns empty list when no games running" do
      # Stop any existing games first
      for game_id <- GameSupervisor.list_games() do
        GameSupervisor.stop_game(game_id)
      end

      assert GameSupervisor.list_games() == []
    end

    test "returns list of active game IDs" do
      # Clean slate
      for game_id <- GameSupervisor.list_games() do
        GameSupervisor.stop_game(game_id)
      end

      {:ok, game_id1} = GameSupervisor.start_game(["Player1"])
      {:ok, game_id2} = GameSupervisor.start_game(["Player2"])
      {:ok, game_id3} = GameSupervisor.start_game(["Player3"])

      game_ids = GameSupervisor.list_games()

      assert length(game_ids) == 3
      assert game_id1 in game_ids
      assert game_id2 in game_ids
      assert game_id3 in game_ids

      # Cleanup
      GameSupervisor.stop_game(game_id1)
      GameSupervisor.stop_game(game_id2)
      GameSupervisor.stop_game(game_id3)
    end

    test "list updates when games are stopped" do
      # Clean slate
      for game_id <- GameSupervisor.list_games() do
        GameSupervisor.stop_game(game_id)
      end

      {:ok, game_id1} = GameSupervisor.start_game(["Player1"])
      {:ok, game_id2} = GameSupervisor.start_game(["Player2"])

      assert length(GameSupervisor.list_games()) == 2

      GameSupervisor.stop_game(game_id1)

      game_ids = GameSupervisor.list_games()
      assert length(game_ids) == 1
      assert game_id2 in game_ids

      # Cleanup
      GameSupervisor.stop_game(game_id2)
    end
  end

  describe "restore_game/1" do
    test "restores a game from saved state" do
      # Create and save a game first
      {:ok, original_id} = GameManager.create_lobby("Host")
      {:ok, original_game} = GameManager.get_game(original_id)

      # Save the game
      GameManager.save_game(original_game)

      # Stop the original game
      GameSupervisor.stop_game(original_id)
      Process.sleep(50)

      # Restore it
      {:ok, restored_id} = GameSupervisor.restore_game(original_game)

      assert restored_id == original_id

      # Should be in registry
      assert [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, restored_id)

      # Can get the restored game
      {:ok, restored_game} = GameManager.get_game(restored_id)
      assert restored_game.id == original_id
      assert restored_game.status == original_game.status

      # Cleanup
      GameSupervisor.stop_game(restored_id)
    end

    test "restore handles game with players" do
      # Create a game with multiple players
      {:ok, game_id} = GameManager.create_ai_game("Player1", 2, :medium)
      {:ok, original_game} = GameManager.get_game(game_id)

      # Save and stop
      GameManager.save_game(original_game)
      GameSupervisor.stop_game(game_id)
      Process.sleep(50)

      # Restore
      {:ok, restored_id} = GameSupervisor.restore_game(original_game)

      {:ok, restored_game} = GameManager.get_game(restored_id)

      # Players should be preserved
      assert length(restored_game.players) == length(original_game.players)

      # Cleanup
      GameSupervisor.stop_game(restored_id)
    end

    test "restore returns error for duplicate game ID" do
      # Create a game
      {:ok, game_id} = GameManager.create_lobby("Host")
      {:ok, game_state} = GameManager.get_game(game_id)

      # Try to restore while original is still running
      result = GameSupervisor.restore_game(game_state)

      # Should get already_started error
      assert {:error, {:already_started, _pid}} = result

      # Cleanup
      GameSupervisor.stop_game(game_id)
    end
  end

  describe "child process supervision" do
    test "supervisor tracks running games" do
      {:ok, game_id} = GameSupervisor.start_game(["Player1"])

      # Get the game process
      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)

      # Process should be alive
      assert Process.alive?(pid)

      # Stop normally
      GameSupervisor.stop_game(game_id)
      Process.sleep(50)

      # Game should be stopped
      assert [] = Registry.lookup(Rachel.GameRegistry, game_id)
    end

    test "can start and stop multiple games independently" do
      {:ok, game_id1} = GameSupervisor.start_game(["Player1"])
      {:ok, game_id2} = GameSupervisor.start_game(["Player2"])

      # Stop game1
      GameSupervisor.stop_game(game_id1)
      Process.sleep(50)

      # Game1 gone, game2 still running
      assert [] = Registry.lookup(Rachel.GameRegistry, game_id1)
      assert [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id2)

      # Cleanup
      GameSupervisor.stop_game(game_id2)
    end
  end
end
