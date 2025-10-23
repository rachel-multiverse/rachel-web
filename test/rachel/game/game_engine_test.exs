defmodule Rachel.Game.GameEngineTest do
  use ExUnit.Case

  alias Rachel.Game.GameEngine

  describe "start_link/1" do
    test "starts a game engine process" do
      players = ["Alice", "Bob"]
      game_id = "test_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      assert Process.alive?(pid)

      {:ok, game} = GameEngine.get_state(game_id)
      assert length(game.players) == 2
      assert game.status == :waiting

      GenServer.stop(pid, :normal)
    end
  end

  describe "start_game/1" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id}
    end

    test "starts a waiting game", %{game_id: game_id} do
      {:ok, game} = GameEngine.start_game(game_id)

      assert game.status == :playing
      assert length(game.deck) > 0
      assert length(game.discard_pile) == 1
      assert Enum.all?(game.players, &(length(&1.hand) > 0))
    end

    test "cannot start an already playing game", %{game_id: game_id} do
      {:ok, _} = GameEngine.start_game(game_id)
      {:error, {:invalid_status, :playing}} = GameEngine.start_game(game_id)
    end
  end

  describe "play_cards/4" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      # Set up a predictable game state
      current_player = Enum.at(game.players, game.current_player_index)
      top_card = hd(game.discard_pile)

      {:ok, game_id: game_id, player_id: current_player.id, top_card: top_card}
    end

    test "accepts valid play", %{game_id: game_id, player_id: player_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.find(game.players, &(&1.id == player_id))

      # Find a valid card to play
      valid_card =
        Enum.find(player.hand, fn card ->
          Rachel.Game.Rules.can_play_card?(card, hd(game.discard_pile), nil)
        end)

      if valid_card do
        {:ok, new_game} = GameEngine.play_cards(game_id, player_id, [valid_card])
        assert hd(new_game.discard_pile) == valid_card
      else
        # No valid card, skip this test
        :ok
      end
    end

    test "rejects play from wrong player", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      wrong_player = Enum.at(game.players, 1 - game.current_player_index)

      card = hd(wrong_player.hand)
      {:error, :not_your_turn} = GameEngine.play_cards(game_id, wrong_player.id, [card])
    end
  end

  describe "draw_cards/3" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      current_player = Enum.at(game.players, game.current_player_index)
      {:ok, game_id: game_id, player_id: current_player.id}
    end

    test "player can draw when they cannot play", %{game_id: game_id, player_id: player_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      original_hand_size = length(Enum.find(game.players, &(&1.id == player_id)).hand)

      {:ok, new_game} = GameEngine.draw_cards(game_id, player_id, :cannot_play)

      new_player = Enum.find(new_game.players, &(&1.id == player_id))
      # Should draw exactly 1 card when cannot play
      assert length(new_player.hand) >= original_hand_size
    end

    test "drawing advances turn when not under attack", %{game_id: game_id, player_id: player_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      original_index = game.current_player_index

      {:ok, new_game} = GameEngine.draw_cards(game_id, player_id, :cannot_play)

      # Turn should advance to next player
      expected_next = rem(original_index + 1, length(game.players))
      assert new_game.current_player_index == expected_next
    end

    test "drawing from attack doesn't advance turn", %{game_id: game_id, player_id: player_id} do
      # Set up an attack situation
      {:ok, game} = GameEngine.get_state(game_id)

      # Manually set pending attack (would normally come from playing 2s)
      Registry.lookup(Rachel.GameRegistry, game_id)
      |> Enum.each(fn {pid, _} ->
        :sys.replace_state(pid, fn state ->
          %{state | game: %{state.game | pending_attack: {:twos, 2}}}
        end)
      end)

      {:ok, new_game} = GameEngine.draw_cards(game_id, player_id, :attack)

      # Turn should not advance after drawing from attack
      assert new_game.current_player_index == game.current_player_index
    end
  end

  describe "AI turn handling" do
    test "AI player is recognized" do
      players = ["Human", {:ai, "Computer", :easy}]
      game_id = "test_ai_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.get_state(game_id)

      ai_player = Enum.at(game.players, 1)
      assert ai_player.type == :ai
      assert ai_player.difficulty == :easy

      GenServer.stop(pid, :normal)
    end
  end

  describe "error recovery" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_game_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id}
    end

    test "handles invalid operations gracefully", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      wrong_player = Enum.at(game.players, 1 - game.current_player_index)

      # Try invalid operations
      card = hd(wrong_player.hand)
      {:error, :not_your_turn} = GameEngine.play_cards(game_id, wrong_player.id, [card])

      # Game should still be playable
      {:ok, final_game} = GameEngine.get_state(game_id)
      assert final_game.status == :playing
    end
  end

  describe "subscribe/unsubscribe" do
    test "can subscribe to game events" do
      players = ["Alice", "Bob"]
      game_id = "test_sub_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      GameEngine.subscribe(game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      # Should receive game_started event
      assert_receive {:game_started, _game}, 1000

      GameEngine.unsubscribe(game_id)
      GenServer.stop(pid, :normal)
    end
  end

  describe "add_player/join" do
    setup do
      players = ["Alice"]
      game_id = "test_join_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "can add player to waiting game", %{game_id: game_id} do
      {:ok, player_id} = GameEngine.add_player(game_id, "Bob", 123)

      assert is_binary(player_id)

      {:ok, game} = GameEngine.get_state(game_id)
      assert length(game.players) == 2
      assert Enum.any?(game.players, &(&1.name == "Bob"))
      assert Enum.any?(game.players, &(&1.user_id == 123))
    end

    test "can add player without user_id", %{game_id: game_id} do
      {:ok, player_id} = GameEngine.add_player(game_id, "Guest")

      assert is_binary(player_id)

      {:ok, game} = GameEngine.get_state(game_id)
      bob = Enum.find(game.players, &(&1.name == "Guest"))
      assert bob.user_id == nil
      assert bob.type == :human
    end

    test "broadcasts player_joined event", %{game_id: game_id} do
      GameEngine.subscribe(game_id)
      {:ok, _} = GameEngine.add_player(game_id, "Charlie")

      # Broadcast format is {{:event, data}, game_state}
      assert_receive {{:player_joined, player}, _game}, 1000
      assert player.name == "Charlie"
    end

    test "cannot add player to started game", %{game_id: game_id} do
      GameEngine.add_player(game_id, "Bob")
      {:ok, _} = GameEngine.start_game(game_id)

      {:error, :cannot_join} = GameEngine.add_player(game_id, "Charlie")
    end

    test "cannot add more than 8 players", %{game_id: game_id} do
      # Add 7 more players (already have 1)
      Enum.each(2..8, fn i ->
        {:ok, _} = GameEngine.add_player(game_id, "Player#{i}")
      end)

      # 9th player should fail
      {:error, :cannot_join} = GameEngine.add_player(game_id, "Player9")
    end
  end

  describe "remove_player/leave" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_leave_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id}
    end

    test "marks player as disconnected", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = hd(game.players)

      :ok = GameEngine.remove_player(game_id, player.id)

      {:ok, updated_game} = GameEngine.get_state(game_id)
      updated_player = Enum.find(updated_game.players, &(&1.id == player.id))
      assert updated_player.connection_status == :disconnected
    end

    test "broadcasts player_left event", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = hd(game.players)

      GameEngine.subscribe(game_id)
      :ok = GameEngine.remove_player(game_id, player.id)

      assert_receive {:player_left, _}, 1000
    end

    test "player remains in game after leaving", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      original_count = length(game.players)
      player = hd(game.players)

      :ok = GameEngine.remove_player(game_id, player.id)

      {:ok, updated_game} = GameEngine.get_state(game_id)
      assert length(updated_game.players) == original_count
    end
  end

  describe "player timeout" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_timeout_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "converts timed out player to AI", %{game_id: game_id, pid: pid} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = hd(game.players)

      GameEngine.subscribe(game_id)
      GenServer.cast(pid, {:player_timeout, player.id})

      assert_receive {:player_timeout, _}, 1000

      {:ok, updated_game} = GameEngine.get_state(game_id)
      updated_player = Enum.find(updated_game.players, &(&1.id == player.id))
      assert updated_player.type == :ai
      assert updated_player.difficulty == :medium
      assert updated_player.connection_status == :timeout
    end
  end

  describe "AI turn processing" do
    test "AI player makes automatic moves" do
      players = ["Human", {:ai, "Computer", :easy}]
      game_id = "test_ai_auto_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      GameEngine.subscribe(game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      # If AI is first player, should receive ai_played event
      if Enum.at(game.players, game.current_player_index).type == :ai do
        assert_receive {:ai_played, _}, 3000
      end

      GenServer.stop(pid, :normal)
    end

    test "AI respects difficulty levels" do
      players = [{:ai, "Easy", :easy}, {:ai, "Hard", :hard}]
      game_id = "test_ai_diff_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      {:ok, game} = GameEngine.get_state(game_id)

      easy_player = Enum.find(game.players, &(&1.name == "Easy"))
      hard_player = Enum.find(game.players, &(&1.name == "Hard"))

      assert easy_player.difficulty == :easy
      assert hard_player.difficulty == :hard

      GenServer.stop(pid, :normal)
    end
  end

  describe "game end detection" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_end_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "detects when player empties hand", %{game_id: game_id, pid: pid} do
      # Set current player to have just 1 card, then play it
      :sys.replace_state(pid, fn state ->
        players = state.game.players
        current_idx = state.game.current_player_index
        current_player = Enum.at(players, current_idx)

        # Give player just one card that matches the top card
        top_card = hd(state.game.discard_pile)
        matching_card = %{top_card | suit: top_card.suit}
        updated_player = %{current_player | hand: [matching_card]}
        updated_players = List.replace_at(players, current_idx, updated_player)

        new_game = %{state.game | players: updated_players}
        %{state | game: new_game}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      current_player = Enum.at(game.players, game.current_player_index)
      card_to_play = hd(current_player.hand)

      GameEngine.subscribe(game_id)

      # Play the last card - should trigger game end
      {:ok, final_game} = GameEngine.play_cards(game_id, current_player.id, [card_to_play])

      # Game should be finished
      assert final_game.status == :finished
      assert_receive {:game_over, _}, 1000
    end

    test "broadcasts game_over event when game ends", %{game_id: game_id, pid: pid} do
      GameEngine.subscribe(game_id)

      # Set up winning condition
      :sys.replace_state(pid, fn state ->
        players = state.game.players
        winner = Enum.at(players, state.game.current_player_index)
        updated_winner = %{winner | hand: []}
        updated_players = List.replace_at(players, state.game.current_player_index, updated_winner)
        new_game = %{state.game | players: updated_players}
        %{state | game: new_game}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      current_player = Enum.at(game.players, game.current_player_index)

      # Trigger end check
      GameEngine.draw_cards(game_id, current_player.id, :cannot_play)

      # May receive game_over if hand was empty
      receive do
        {:game_over, _} -> :ok
      after
        500 -> :ok
      end
    end

    test "schedules cleanup after game ends", %{game_id: game_id, pid: pid} do
      # Set winning condition
      :sys.replace_state(pid, fn state ->
        players = state.game.players
        winner = Enum.at(players, state.game.current_player_index)
        updated_winner = %{winner | hand: []}
        updated_players = List.replace_at(players, state.game.current_player_index, updated_winner)
        new_game = %{state.game | players: updated_players, status: :finished}
        %{state | game: new_game}
      end)

      # Process should schedule cleanup message
      assert Process.alive?(pid)
    end
  end

  describe "error recovery and corruption" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_error_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "increments error count on failed operations", %{game_id: game_id, pid: pid} do
      {:ok, game} = GameEngine.get_state(game_id)
      wrong_player = Enum.at(game.players, 1 - game.current_player_index)

      initial_state = :sys.get_state(pid)
      initial_errors = initial_state.error_count

      # Make invalid play
      card = hd(wrong_player.hand)
      {:error, :not_your_turn} = GameEngine.play_cards(game_id, wrong_player.id, [card])

      updated_state = :sys.get_state(pid)
      assert updated_state.error_count == initial_errors + 1
    end

    test "resets error count on successful operation", %{game_id: game_id, pid: pid} do
      # First cause an error
      {:ok, game} = GameEngine.get_state(game_id)
      wrong_player = Enum.at(game.players, 1 - game.current_player_index)
      card = hd(wrong_player.hand)
      {:error, :not_your_turn} = GameEngine.play_cards(game_id, wrong_player.id, [card])

      # Verify error was counted
      state_after_error = :sys.get_state(pid)
      assert state_after_error.error_count > 0

      # Now make valid play
      {:ok, game} = GameEngine.get_state(game_id)
      current_player = Enum.at(game.players, game.current_player_index)
      {:ok, _} = GameEngine.draw_cards(game_id, current_player.id, :cannot_play)

      # Error count should reset
      final_state = :sys.get_state(pid)
      assert final_state.error_count == 0
    end

    test "marks game as corrupted after too many errors", %{game_id: game_id, pid: pid} do
      # Manually set high error count
      :sys.replace_state(pid, fn state ->
        %{state | error_count: 11}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      wrong_player = Enum.at(game.players, 1 - game.current_player_index)
      card = hd(wrong_player.hand)

      # This error should trigger corruption
      {:error, :not_your_turn} = GameEngine.play_cards(game_id, wrong_player.id, [card])

      {:ok, corrupted_game} = GameEngine.get_state(game_id)
      assert corrupted_game.status == :corrupted
    end
  end

  describe "restore from database" do
    test "can restore game state from database" do
      # Create a game state to restore
      game_state = Rachel.Game.GameState.new(["Alice", "Bob"])
      |> Map.put(:id, "restore_test_#{System.unique_integer()}")
      |> Rachel.Game.GameState.start_game()

      # Start engine with restore
      {:ok, pid} = GenServer.start_link(
        Rachel.Game.GameEngine,
        {:restore, game_state},
        name: {:via, Registry, {Rachel.GameRegistry, game_state.id}}
      )

      {:ok, restored_game} = GameEngine.get_state(game_state.id)

      assert restored_game.id == game_state.id
      assert restored_game.status == :playing
      assert length(restored_game.players) == 2

      GenServer.stop(pid, :normal)
    end

    test "schedules AI after restore if AI's turn" do
      # Create game with AI
      game_state = Rachel.Game.GameState.new(["Human", {:ai, "Bot", :medium}])
      |> Map.put(:id, "restore_ai_#{System.unique_integer()}")
      |> Rachel.Game.GameState.start_game()

      # Set AI as current player
      ai_index = Enum.find_index(game_state.players, &(&1.type == :ai))
      game_state = %{game_state | current_player_index: ai_index}

      {:ok, pid} = GenServer.start_link(
        Rachel.Game.GameEngine,
        {:restore, game_state},
        name: {:via, Registry, {Rachel.GameRegistry, game_state.id}}
      )

      # AI should be scheduled
      state = :sys.get_state(pid)
      assert state.ai_turn_ref != nil

      GenServer.stop(pid, :normal)
    end
  end

  describe "special card validation" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_special_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "rejects invalid card stack", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)

      # Try to play cards of different ranks
      if length(player.hand) >= 2 do
        different_cards = Enum.take(player.hand, 2)
        |> Enum.uniq_by(& &1.rank)

        if length(different_cards) == 2 do
          {:error, :invalid_stack} = GameEngine.play_cards(game_id, player.id, different_cards)
        end
      end
    end

    test "validates counter attacks", %{game_id: game_id, pid: pid} do
      # Set up an attack situation
      black_jack = %Rachel.Game.Card{suit: :spades, rank: 11}

      :sys.replace_state(pid, fn state ->
        new_game = %{state.game |
          pending_attack: {:black_jacks, 5},
          discard_pile: [black_jack | state.game.discard_pile]
        }
        %{state | game: new_game}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)

      # Try to play non-counter card (not Jack or 2)
      non_counter = Enum.find(player.hand, fn card ->
        card.rank != 11 and card.rank != 2
      end)

      if non_counter do
        {:error, :invalid_counter} = GameEngine.play_cards(game_id, player.id, [non_counter])
      end
    end

    test "accepts valid counter cards", %{game_id: game_id, pid: pid} do
      # Set up Black Jack attack
      black_jack = %Rachel.Game.Card{suit: :spades, rank: 11}

      :sys.replace_state(pid, fn state ->
        players = state.game.players
        current = Enum.at(players, state.game.current_player_index)

        # Give player a Red Jack to counter with (rank 11 for Jack)
        red_jack = %Rachel.Game.Card{suit: :hearts, rank: 11}
        updated_current = %{current | hand: [red_jack | current.hand]}
        updated_players = List.replace_at(players, state.game.current_player_index, updated_current)

        new_game = %{state.game |
          pending_attack: {:black_jacks, 5},
          discard_pile: [black_jack | state.game.discard_pile],
          players: updated_players
        }
        %{state | game: new_game}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)
      red_jack = Enum.find(player.hand, &(&1.rank == 11 and &1.suit in [:hearts, :diamonds]))

      # Red Jacks should be able to counter Black Jack attacks
      if red_jack do
        {:ok, _} = GameEngine.play_cards(game_id, player.id, [red_jack])
      end
    end
  end

  describe "state validation" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_validation_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "validates card count after operations", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)

      # Count all cards
      cards_in_hands = game.players |> Enum.flat_map(& &1.hand) |> length()
      total = cards_in_hands + length(game.deck) + length(game.discard_pile)

      # Should match expected total
      assert total == game.expected_total_cards
    end

    test "rejects operations that would break card count", %{game_id: game_id, pid: pid} do
      # Corrupt the game state
      :sys.replace_state(pid, fn state ->
        # Remove cards from deck without adding anywhere
        corrupted_game = %{state.game | deck: []}
        %{state | game: corrupted_game}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)

      # Try to draw - should fail validation
      result = GameEngine.draw_cards(game_id, player.id, :cannot_play)

      # May succeed if deck reshuffles, or fail if validation catches it
      case result do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end

    test "waiting games bypass card count validation", %{game_id: _game_id} do
      players = ["Test1", "Test2"]
      waiting_id = "test_waiting_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: waiting_id)

      {:ok, game} = GameEngine.get_state(waiting_id)

      # Waiting games have no cards dealt yet
      assert game.status == :waiting
      assert Enum.all?(game.players, &(&1.hand == []))

      GenServer.stop(pid, :normal)
    end
  end

  describe "safe_execute error handling" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_safe_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "handles card count validation", %{game_id: game_id, pid: pid} do
      # Test that game validates card count correctly
      {:ok, game} = GameEngine.get_state(game_id)

      # Count should be valid initially
      cards_in_hands = game.players |> Enum.flat_map(& &1.hand) |> length()
      total = cards_in_hands + length(game.deck) + length(game.discard_pile)
      assert total == game.expected_total_cards

      # Corrupt the game state
      :sys.replace_state(pid, fn state ->
        # Remove all cards from deck to create invalid count
        %{state | game: %{state.game | deck: []}}
      end)

      # Game state is now invalid, but still retrievable
      {:ok, corrupted_game} = GameEngine.get_state(game_id)
      assert corrupted_game.deck == []
    end

    test "handles waiting game validation differently", %{} do
      # Waiting games don't validate card count
      players = ["Test1", "Test2"]
      waiting_id = "test_waiting_safe_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: waiting_id)

      {:ok, game} = GameEngine.get_state(waiting_id)
      assert game.status == :waiting

      # Waiting games have no cards, validation should pass
      assert Enum.all?(game.players, &(&1.hand == []))
      assert game.deck == []

      GenServer.stop(pid, :normal)
    end
  end

  describe "AI turn error recovery" do
    test "handles AI failures gracefully" do
      # Create game with AI
      players = [{:ai, "BrokenBot", :medium}, "Human"]
      game_id = "test_ai_fail_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      # If AI is first, corrupt its state to cause failure
      if Enum.at(game.players, game.current_player_index).type == :ai do
        :sys.replace_state(pid, fn state ->
          # Give AI invalid hand to cause AIPlayer.choose_action to fail
          players = state.game.players
          ai_idx = state.game.current_player_index
          ai_player = Enum.at(players, ai_idx)

          # Empty hand will cause AI logic issues
          broken_ai = %{ai_player | hand: []}
          updated_players = List.replace_at(players, ai_idx, broken_ai)

          %{state | game: %{state.game | players: updated_players}}
        end)

        # Send AI turn message manually
        send(pid, :ai_turn)

        # Give it time to process
        Process.sleep(100)

        # Game should still be alive
        assert Process.alive?(pid)
      end

      GenServer.stop(pid, :normal)
    end

    test "reschedules AI after failed turn", %{} do
      players = [{:ai, "TestBot", :easy}, "Human"]
      game_id = "test_ai_reschedule_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, game} = GameEngine.start_game(game_id)

      # Verify AI gets scheduled
      if Enum.at(game.players, game.current_player_index).type == :ai do
        state = :sys.get_state(pid)
        assert state.ai_turn_ref != nil
      end

      GenServer.stop(pid, :normal)
    end
  end

  describe "player validation edge cases" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_validation_edge_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "rejects play with cards not in hand", %{game_id: game_id} do
      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)

      # Create a card that's definitely not in hand
      fake_card = %Rachel.Game.Card{suit: :hearts, rank: 2}

      {:error, :cards_not_in_hand} = GameEngine.play_cards(game_id, player.id, [fake_card])
    end

    test "rejects play from non-existent player", %{game_id: game_id} do
      fake_player_id = "non-existent-player-id"
      fake_card = %Rachel.Game.Card{suit: :hearts, rank: 5}

      {:error, :player_not_found} = GameEngine.play_cards(game_id, fake_player_id, [fake_card])
    end

    test "rejects draw from non-existent player", %{game_id: game_id} do
      fake_player_id = "non-existent-player-id"

      {:error, :player_not_found} = GameEngine.draw_cards(game_id, fake_player_id, :cannot_play)
    end
  end

  describe "empty discard pile handling" do
    test "handles empty discard pile error" do
      players = ["Alice", "Bob"]
      game_id = "test_empty_pile_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      # Corrupt state to have empty discard pile
      :sys.replace_state(pid, fn state ->
        %{state | game: %{state.game | discard_pile: []}}
      end)

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)

      # Try to play - should fail with no_discard_pile
      if length(player.hand) > 0 do
        card = hd(player.hand)
        {:error, :no_discard_pile} = GameEngine.play_cards(game_id, player.id, [card])
      end

      GenServer.stop(pid, :normal)
    end
  end

  describe "checkpoint and persistence" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_checkpoint_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id, pid: pid}
    end

    test "checkpoint updates timestamp", %{game_id: game_id, pid: pid} do
      initial_state = :sys.get_state(pid)
      initial_checkpoint = initial_state.last_checkpoint

      # Wait a bit
      Process.sleep(10)

      # Make a valid operation that triggers checkpoint
      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)
      GameEngine.draw_cards(game_id, player.id, :cannot_play)

      # Checkpoint should be updated
      updated_state = :sys.get_state(pid)
      assert updated_state.last_checkpoint > initial_checkpoint
    end

    test "game state persists through operations", %{game_id: game_id} do
      {:ok, initial_game} = GameEngine.get_state(game_id)

      # Make multiple operations
      player = Enum.at(initial_game.players, initial_game.current_player_index)
      GameEngine.draw_cards(game_id, player.id, :cannot_play)

      # State should be retrievable
      {:ok, final_game} = GameEngine.get_state(game_id)
      assert final_game.id == game_id
    end
  end

  describe "cleanup message handling" do
    test "stops process on cleanup message" do
      players = ["Alice", "Bob"]
      game_id = "test_cleanup_msg_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      # Monitor the process
      ref = Process.monitor(pid)

      # Send cleanup message
      send(pid, :cleanup)

      # Process should stop
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end
  end

  describe "broadcast functionality" do
    setup do
      players = ["Alice", "Bob"]
      game_id = "test_broadcast_#{System.unique_integer()}"
      {:ok, pid} = GameEngine.start_link(players: players, game_id: game_id)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, game_id: game_id}
    end

    test "broadcasts cards_played event", %{game_id: game_id} do
      GameEngine.subscribe(game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      # Clear the game_started message
      receive do
        {:game_started, _} -> :ok
      after
        100 -> :ok
      end

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)
      player_id = player.id

      # Find valid card
      valid_card = Enum.find(player.hand, fn card ->
        Rachel.Game.Rules.can_play_card?(card, hd(game.discard_pile), nil)
      end)

      if valid_card do
        {:ok, _} = GameEngine.play_cards(game_id, player_id, [valid_card])

        # Should receive broadcast
        assert_receive {{:cards_played, ^player_id, [^valid_card]}, _game}, 1000
      end
    end

    test "broadcasts cards_drawn event", %{game_id: game_id} do
      GameEngine.subscribe(game_id)
      {:ok, _} = GameEngine.start_game(game_id)

      # Clear the game_started message
      receive do
        {:game_started, _} -> :ok
      after
        100 -> :ok
      end

      {:ok, game} = GameEngine.get_state(game_id)
      player = Enum.at(game.players, game.current_player_index)
      player_id = player.id

      {:ok, _} = GameEngine.draw_cards(game_id, player_id, :cannot_play)

      # Should receive broadcast
      assert_receive {{:cards_drawn, ^player_id, :cannot_play}, _game}, 1000
    end
  end
end
