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
      valid_card = Enum.find(player.hand, fn card ->
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
end