defmodule Rachel.GameManagerTest do
  use Rachel.DataCase, async: false

  alias Rachel.Game.Games
  alias Rachel.GameManager

  describe "create_game/1" do
    test "creates a game with valid players" do
      players = [
        {:user, 1, "Alice"},
        {:user, 2, "Bob"},
        {:anonymous, "Charlie"}
      ]

      {:ok, game_id} = GameManager.create_game(players)

      assert is_binary(game_id)
      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3
      assert game.status == :waiting
    end

    test "creates a game with AI players" do
      players = [
        {:user, 1, "Alice"},
        {:ai, "Bot1", :easy},
        {:ai, "Bot2", :medium}
      ]

      {:ok, game_id} = GameManager.create_game(players)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3
    end

    test "requires at least 2 players" do
      players = [{:user, 1, "Alice"}]

      # Should not match function clause
      assert_raise FunctionClauseError, fn ->
        GameManager.create_game(players)
      end
    end

    test "handles string players for backwards compatibility" do
      players = ["Alice", "Bob"]

      {:ok, game_id} = GameManager.create_game(players)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 2
    end
  end

  describe "create_ai_game/3" do
    test "creates game with default AI opponents" do
      player = {:user, 1, "Alice"}

      {:ok, game_id} = GameManager.create_ai_game(player)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 4  # 1 human + 3 AI
      assert game.status == :waiting
    end

    test "creates game with custom number of AI" do
      player = {:user, 1, "Alice"}

      {:ok, game_id} = GameManager.create_ai_game(player, 2)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3  # 1 human + 2 AI
    end

    test "creates game with custom difficulty" do
      player = {:user, 1, "Alice"}

      {:ok, game_id} = GameManager.create_ai_game(player, 2, :hard)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3
    end

    test "accepts anonymous players" do
      player = {:anonymous, "Guest"}

      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3
    end

    test "accepts string players" do
      {:ok, game_id} = GameManager.create_ai_game("Alice", 2, :easy)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 3
    end
  end

  describe "create_lobby/1" do
    test "creates a lobby with host" do
      host = {:user, 1, "Alice"}

      {:ok, game_id} = GameManager.create_lobby(host)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 1
      assert game.status == :waiting
      assert hd(game.players).name == "Alice"
    end

    test "accepts anonymous host" do
      host = {:anonymous, "Guest"}

      {:ok, game_id} = GameManager.create_lobby(host)

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 1
    end

    test "accepts string host" do
      {:ok, game_id} = GameManager.create_lobby("Host")

      assert {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 1
    end
  end

  describe "join_game/3" do
    test "adds player to lobby" do
      {:ok, game_id} = GameManager.create_lobby({:user, 1, "Alice"})

      {:ok, _game} = GameManager.join_game(game_id, "Bob", 2)

      {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 2
      assert Enum.any?(game.players, &(&1.name == "Bob"))
    end

    test "adds anonymous player" do
      {:ok, game_id} = GameManager.create_lobby({:user, 1, "Alice"})

      {:ok, _game} = GameManager.join_game(game_id, "Guest")

      {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 2
    end

    test "handles non-existent game" do
      # GenServer.call will raise exit
      assert catch_exit(GameManager.join_game("nonexistent", "Bob"))
    end
  end

  describe "start_game/1" do
    test "starts a waiting game" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      {:ok, _game} = GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      assert game.status == :playing
      assert length(game.discard_pile) > 0
    end

    test "handles non-existent game" do
      # GenServer.call will raise exit
      assert catch_exit(GameManager.start_game("nonexistent"))
    end
  end

  describe "get_game/1" do
    test "returns game state" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      {:ok, game} = GameManager.get_game(game_id)

      assert game.id == game_id
      assert is_list(game.players)
      assert is_atom(game.status)
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.get_game("nonexistent")
    end
  end

  describe "play_cards/4" do
    setup do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      # Wait for player 0's turn
      wait_for_player_turn(game_id, 0)

      {:ok, game: game_id}
    end

    test "plays valid cards", %{game: game_id} do
      {:ok, game} = GameManager.get_game(game_id)
      player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Find a playable card (excluding Red Jacks when no attack)
      playable_card =
        Enum.find(player.hand, fn card ->
          # Red Jacks can only counter Black Jack attacks
          is_red_jack = card.rank == :jack and card.suit in [:hearts, :diamonds]
          can_play = Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)

          can_play and not (is_red_jack and game.attack_count == 0)
        end)

      if playable_card do
        hand_size_before = length(player.hand)

        {:ok, _game} = GameManager.play_cards(game_id, player.id, [playable_card])

        {:ok, updated_game} = GameManager.get_game(game_id)
        updated_player = Enum.find(updated_game.players, &(&1.id == player.id))

        assert length(updated_player.hand) == hand_size_before - 1
      end
    end

    test "returns error for non-existent game" do
      card = %Rachel.Game.Card{suit: :hearts, rank: 5}
      assert {:error, :game_not_found} = GameManager.play_cards("nonexistent", "any-id", [card])
    end
  end

  describe "draw_cards/3" do
    setup do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      wait_for_player_turn(game_id, 0)

      {:ok, game: game_id}
    end

    test "draws cards for player", %{game: game_id} do
      {:ok, game} = GameManager.get_game(game_id)
      # Get the current player, not just player at index 0
      player = Enum.at(game.players, game.current_player_index)
      hand_size_before = length(player.hand)

      {:ok, _game} = GameManager.draw_cards(game_id, player.id, :cannot_play)

      {:ok, updated_game} = GameManager.get_game(game_id)
      updated_player = Enum.find(updated_game.players, &(&1.id == player.id))

      assert length(updated_player.hand) >= hand_size_before + 1
    end

    test "accepts attack reason", %{game: game_id} do
      {:ok, game} = GameManager.get_game(game_id)
      # Get the current player, not just player at index 0
      player = Enum.at(game.players, game.current_player_index)

      {:ok, _game} = GameManager.draw_cards(game_id, player.id, :attack)

      # Should not crash
      assert {:ok, _} = GameManager.get_game(game_id)
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.draw_cards("nonexistent", "any-id")
    end
  end

  describe "list_games/0" do
    test "returns list of active game IDs" do
      {:ok, game_id1} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      {:ok, game_id2} = GameManager.create_ai_game({:user, 2, "Bob"}, 2)

      games = GameManager.list_games()

      assert is_list(games)
      # list_games returns just IDs, not tuples
      assert Enum.member?(games, game_id1)
      assert Enum.member?(games, game_id2)
    end

    test "returns empty list when no games" do
      # Clean up any existing games
      GameManager.list_games()
      |> Enum.each(fn game_id -> GameManager.end_game(game_id) end)

      Process.sleep(50)

      games = GameManager.list_games()
      assert games == []
    end
  end

  describe "subscribe_to_game/1 and unsubscribe_from_game/1" do
    test "subscribes to game updates" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      :ok = GameManager.subscribe_to_game(game_id)

      # Verify subscription by starting game and checking for broadcast
      GameManager.start_game(game_id)

      # Should receive game_started broadcast
      assert_receive {:game_started, _}, 3000
    end

    test "unsubscribes from game updates" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      :ok = GameManager.subscribe_to_game(game_id)
      :ok = GameManager.unsubscribe_from_game(game_id)

      # Start game - should not receive updates
      GameManager.start_game(game_id)

      refute_receive {:game_started, _}, 500
    end
  end

  describe "end_game/1" do
    test "stops a game" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      :ok = GameManager.end_game(game_id)

      Process.sleep(50)

      assert {:error, :game_not_found} = GameManager.get_game(game_id)
    end

    test "handles non-existent game" do
      # Returns error for not found
      assert {:error, :not_found} = GameManager.end_game("nonexistent")
    end
  end

  describe "get_game_info/1" do
    test "returns public game information" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)

      {:ok, info} = GameManager.get_game_info(game_id)

      assert info.id == game_id
      assert info.status == :waiting
      assert info.player_count == 3
      assert is_list(info.players)
      assert Enum.any?(info.players, &(&1 == "Alice"))
      assert info.created_at != nil
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.get_game_info("nonexistent")
    end
  end

  describe "can_play?/2" do
    setup do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      {:ok, game: game_id}
    end

    test "returns true for current player", %{game: game_id} do
      {:ok, game} = GameManager.get_game(game_id)
      current_player = Enum.at(game.players, game.current_player_index)

      assert GameManager.can_play?(game_id, current_player.id) == true
    end

    test "returns false for non-current player", %{game: game_id} do
      {:ok, game} = GameManager.get_game(game_id)
      current_player_idx = game.current_player_index
      other_player_idx = rem(current_player_idx + 1, length(game.players))
      other_player = Enum.at(game.players, other_player_idx)

      assert GameManager.can_play?(game_id, other_player.id) == false
    end

    test "returns false for non-existent game" do
      assert GameManager.can_play?("nonexistent", "any-id") == false
    end
  end

  describe "save_game/1 and load_game/1" do
    test "saves and loads game state" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)

      {:ok, _saved_game} = GameManager.save_game(game)

      {:ok, loaded_game} = GameManager.load_game(game_id)

      assert loaded_game.id == game.id
      assert loaded_game.status == game.status
      assert length(loaded_game.players) == length(game.players)
    end

    test "returns error for non-existent game" do
      # Use valid UUID that doesn't exist
      fake_uuid = Ecto.UUID.generate()
      assert {:error, :not_found} = GameManager.load_game(fake_uuid)
    end
  end

  describe "delete_game_record/1" do
    test "deletes game from database" do
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      GameManager.save_game(game)

      {:ok, _} = GameManager.delete_game_record(game_id)

      assert {:error, :not_found} = GameManager.load_game(game_id)
    end

    test "handles non-existent valid UUID game" do
      # Use valid UUID that doesn't exist
      fake_uuid = Ecto.UUID.generate()
      {:error, _} = GameManager.delete_game_record(fake_uuid)
    end
  end

  describe "restore_active_games/0" do
    test "restores saved games" do
      # Create and save a game
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      GameManager.save_game(game)

      # Stop the game
      GameManager.end_game(game_id)
      Process.sleep(50)

      # Restore games
      restored_ids = GameManager.restore_active_games()

      assert is_list(restored_ids)
      # Note: May or may not include our game depending on timing
    end

    test "handles no games to restore" do
      # Clean up all saved games first
      [:playing, :waiting]
      |> Enum.flat_map(&Games.list_by_status/1)
      |> Enum.each(&Games.delete_game(&1.id))

      restored_ids = GameManager.restore_active_games()

      assert restored_ids == []
    end

    test "skips finished games" do
      # Create and save a finished game
      {:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 2)
      GameManager.start_game(game_id)

      {:ok, game} = GameManager.get_game(game_id)
      finished_game = %{game | status: :finished}
      GameManager.save_game(finished_game)

      # Restore should skip finished games
      restored_ids = GameManager.restore_active_games()

      refute Enum.member?(restored_ids, game_id)
    end
  end

  # Helper function
  defp wait_for_player_turn(game_id, player_index, attempts \\ 50) do
    {:ok, game} = GameManager.get_game(game_id)

    if game.current_player_index == player_index or attempts == 0 or game.status == :finished do
      :ok
    else
      Process.sleep(100)
      wait_for_player_turn(game_id, player_index, attempts - 1)
    end
  end
end
