defmodule Rachel.GameServerTest do
  use ExUnit.Case, async: true

  alias Rachel.GameManager

  # No setup needed - application supervisor starts these

  describe "game lifecycle" do
    test "creates a new game with players" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      assert {:ok, game} = GameManager.get_game(game_id)
      
      assert game.status == :waiting
      assert length(game.players) == 2
      assert Enum.map(game.players, & &1.name) == ["Alice", "Bob"]
    end

    test "starts a game" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      {:ok, game} = GameManager.start_game(game_id)
      
      assert game.status == :playing
      # Each player should have cards
      assert Enum.all?(game.players, fn p -> length(p.hand) == 7 end)
      # Should have a discard pile
      assert length(game.discard_pile) == 1
    end

    test "prevents starting an already started game" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      {:ok, _} = GameManager.start_game(game_id)
      
      # Try to start again
      assert {:error, {:invalid_status, :playing}} = GameManager.start_game(game_id)
    end
  end

  describe "lobby functionality" do
    test "creates a lobby and allows players to join" do
      {:ok, game_id} = GameManager.create_lobby("Host")
      {:ok, player_id} = GameManager.join_game(game_id, "Guest")
      
      {:ok, game} = GameManager.get_game(game_id)
      assert length(game.players) == 2
      assert Enum.map(game.players, & &1.name) == ["Host", "Guest"]
      assert player_id
    end

    test "prevents joining a full game" do
      # Create game with 8 players (max)
      players = for i <- 1..8, do: "Player#{i}"
      {:ok, game_id} = GameManager.create_game(players)
      
      # Try to join
      assert {:error, :cannot_join} = GameManager.join_game(game_id, "Extra")
    end

    test "prevents joining a started game" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      {:ok, _} = GameManager.start_game(game_id)
      
      assert {:error, :cannot_join} = GameManager.join_game(game_id, "Charlie")
    end
  end

  describe "game actions" do
    setup do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      {:ok, game} = GameManager.start_game(game_id)
      
      %{game_id: game_id, game: game}
    end

    test "player can play valid cards", %{game_id: game_id, game: game} do
      current_player = Enum.at(game.players, game.current_player_index)
      top_card = hd(game.discard_pile)
      
      # Find a valid card to play
      valid_card = Enum.find(current_player.hand, fn card ->
        card.suit == top_card.suit || card.rank == top_card.rank
      end)
      
      if valid_card do
        {:ok, new_game} = GameManager.play_cards(game_id, current_player.id, [valid_card])
        
        # Card should be on discard pile
        assert hd(new_game.discard_pile) == valid_card
        
        # Turn should advance (for 2 players, will go 0->1 or 1->0)
        expected_next = if game.current_player_index == 0, do: 1, else: 0
        assert new_game.current_player_index == expected_next
      end
    end

    test "player can draw when they cannot play", %{game_id: game_id, game: game} do
      current_player = Enum.at(game.players, game.current_player_index)
      initial_hand_size = length(current_player.hand)
      
      {:ok, new_game} = GameManager.draw_cards(game_id, current_player.id, :cannot_play)
      
      # Player should have drawn a card
      new_player = Enum.at(new_game.players, game.current_player_index)
      assert length(new_player.hand) == initial_hand_size + 1
      
      # Turn should advance
      assert new_game.current_player_index != game.current_player_index
    end

    test "prevents out-of-turn play", %{game_id: game_id, game: game} do
      # Get non-current player
      other_player_index = if game.current_player_index == 0, do: 1, else: 0
      other_player = Enum.at(game.players, other_player_index)
      
      # Try to play out of turn
      result = GameManager.play_cards(game_id, other_player.id, [hd(other_player.hand)])
      assert {:error, :not_your_turn} = result
    end
  end

  describe "pubsub events" do
    test "broadcasts game events" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      
      # Subscribe to game events
      GameManager.subscribe_to_game(game_id)
      
      # Start the game
      {:ok, _} = GameManager.start_game(game_id)
      
      # Should receive broadcast
      assert_receive {:game_started, _game}, 1000
    end

    test "broadcasts when cards are played" do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      {:ok, game} = GameManager.start_game(game_id)
      
      GameManager.subscribe_to_game(game_id)
      
      current_player = Enum.at(game.players, game.current_player_index)
      top_card = hd(game.discard_pile)
      
      # Find and play a valid card
      valid_card = Enum.find(current_player.hand, fn card ->
        card.suit == top_card.suit || card.rank == top_card.rank
      end)
      
      if valid_card do
        {:ok, _} = GameManager.play_cards(game_id, current_player.id, [valid_card])
        assert_receive {{:cards_played, _, _}, _game}, 1000
      end
    end
  end

  describe "error handling" do
    test "handles non-existent game gracefully" do
      fake_id = Ecto.UUID.generate()
      
      assert {:error, :game_not_found} = GameManager.get_game(fake_id)
      assert {:error, :game_not_found} = GameManager.play_cards(fake_id, "player", [])
      assert {:error, :game_not_found} = GameManager.draw_cards(fake_id, "player")
    end
  end
end