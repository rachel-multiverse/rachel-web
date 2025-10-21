defmodule Rachel.Game.GamesTest do
  use Rachel.DataCase, async: false

  alias Rachel.Game.{Card, Games, GameState}

  describe "save_game/1 and load_game/1" do
    test "saves and loads a waiting game" do
      game =
        GameState.new([
          {:user, 1, "Alice"},
          {:anonymous, "Bob"}
        ])

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      assert loaded.id == game.id
      assert loaded.status == :waiting
      assert length(loaded.players) == 2
      assert Enum.at(loaded.players, 0).name == "Alice"
      assert Enum.at(loaded.players, 0).user_id == 1
      assert Enum.at(loaded.players, 1).name == "Bob"
      assert Enum.at(loaded.players, 1).user_id == nil
    end

    test "saves and loads a playing game with full state" do
      game =
        GameState.new([
          {:user, 1, "Alice"},
          {:anonymous, "Bob"}
        ])
        |> GameState.start_game()

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      assert loaded.status == :playing
      assert length(loaded.deck) == length(game.deck)
      assert length(loaded.discard_pile) == 1
      assert loaded.current_player_index == game.current_player_index
      assert loaded.direction == game.direction
      assert loaded.turn_count == 0
    end

    test "saves and loads pending attack state" do
      game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:pending_attack, {:twos, 4})

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      assert loaded.pending_attack == {:twos, 4}
    end

    test "saves and loads nominated suit" do
      game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:nominated_suit, :hearts)

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      assert loaded.nominated_suit == :hearts
    end

    test "saves and loads AI players with difficulty" do
      game =
        GameState.new([
          {:ai, "AI-Easy", :easy},
          {:ai, "AI-Hard", :hard}
        ])

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      ai1 = Enum.at(loaded.players, 0)
      ai2 = Enum.at(loaded.players, 1)

      assert ai1.type == :ai
      assert ai1.difficulty == :easy
      assert ai2.type == :ai
      assert ai2.difficulty == :hard
    end

    test "saves and loads player hands correctly" do
      game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()

      # Player should have cards in hand
      player = Enum.at(game.players, 0)
      assert length(player.hand) > 0

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      loaded_player = Enum.at(loaded.players, 0)
      assert length(loaded_player.hand) == length(player.hand)

      # Check first card matches
      original_card = hd(player.hand)
      loaded_card = hd(loaded_player.hand)
      assert loaded_card.suit == original_card.suit
      assert loaded_card.rank == original_card.rank
    end

    test "upserts on conflict" do
      game = GameState.new([{:anonymous, "Alice"}])

      # First save
      assert {:ok, _} = Games.save_game(game)

      # Modify and save again
      modified = Map.put(game, :turn_count, 5)
      assert {:ok, _} = Games.save_game(modified)

      # Should have updated, not created duplicate
      assert {:ok, loaded} = Games.load_game(game.id)
      assert loaded.turn_count == 5
    end

    test "returns error for non-existent game" do
      fake_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Games.load_game(fake_id)
    end
  end

  describe "delete_game/1" do
    test "deletes an existing game" do
      game = GameState.new([{:anonymous, "Alice"}])
      assert {:ok, _} = Games.save_game(game)

      assert {:ok, _} = Games.delete_game(game.id)
      assert {:error, :not_found} = Games.load_game(game.id)
    end

    test "returns error for non-existent game" do
      fake_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Games.delete_game(fake_id)
    end
  end

  describe "list_by_status/1" do
    test "lists games by status" do
      waiting_game = GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])

      playing_game =
        GameState.new([{:anonymous, "Charlie"}, {:anonymous, "Dave"}])
        |> GameState.start_game()

      finished_game =
        GameState.new([{:anonymous, "Eve"}, {:anonymous, "Frank"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)

      Games.save_game(waiting_game)
      Games.save_game(playing_game)
      Games.save_game(finished_game)

      waiting_list = Games.list_by_status(:waiting)
      playing_list = Games.list_by_status(:playing)
      finished_list = Games.list_by_status(:finished)

      assert Enum.any?(waiting_list, &(&1.id == waiting_game.id))
      assert Enum.any?(playing_list, &(&1.id == playing_game.id))
      assert Enum.any?(finished_list, &(&1.id == finished_game.id))
    end

    test "returns empty list for status with no games" do
      assert [] = Games.list_by_status(:corrupted)
    end
  end

  describe "list_stale_games/0" do
    test "lists finished games older than 1 hour" do
      old_game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3700, :second))

      Games.save_game(old_game)

      stale_games = Games.list_stale_games()
      assert old_game.id in stale_games
    end

    test "lists waiting games inactive for 30 minutes" do
      old_lobby =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -1900, :second))

      Games.save_game(old_lobby)

      stale_games = Games.list_stale_games()
      assert old_lobby.id in stale_games
    end

    test "lists playing games inactive for 2 hours" do
      abandoned_game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -7300, :second))

      Games.save_game(abandoned_game)

      stale_games = Games.list_stale_games()
      assert abandoned_game.id in stale_games
    end

    test "does not list recent games" do
      recent_game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()

      Games.save_game(recent_game)

      stale_games = Games.list_stale_games()
      refute recent_game.id in stale_games
    end
  end

  describe "card serialization" do
    test "preserves all card properties" do
      cards = [
        Card.new(:hearts, 14),
        Card.new(:spades, 13),
        Card.new(:diamonds, 2),
        Card.new(:clubs, 11)
      ]

      game =
        GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}])
        |> Map.put(:discard_pile, cards)

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      loaded_cards = loaded.discard_pile

      Enum.zip(cards, loaded_cards)
      |> Enum.each(fn {original, loaded} ->
        assert loaded.suit == original.suit
        assert loaded.rank == original.rank
      end)
    end
  end

  describe "multi-deck games" do
    test "saves and loads games with multiple decks" do
      game = GameState.new([{:anonymous, "Alice"}, {:anonymous, "Bob"}], deck_count: 2)

      assert {:ok, _} = Games.save_game(game)
      assert {:ok, loaded} = Games.load_game(game.id)

      assert loaded.deck_count == 2
      assert loaded.expected_total_cards == 104
    end
  end
end
