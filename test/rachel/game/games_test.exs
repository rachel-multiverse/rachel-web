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

  describe "record_user_participation/1" do
    setup do
      # Create test users
      {:ok, user1} =
        Rachel.Accounts.register_user(%{
          email: "alice@example.com",
          username: "alice",
          password: "alicepassword123"
        })

      {:ok, user2} =
        Rachel.Accounts.register_user(%{
          email: "bob@example.com",
          username: "bob",
          password: "bobpassword1234"
        })

      {:ok, user3} =
        Rachel.Accounts.register_user(%{
          email: "charlie@example.com",
          username: "charlie",
          password: "charliepassword1"
        })

      %{user1: user1, user2: user2, user3: user3}
    end

    test "records participation for finished game with human players", %{
      user1: user1,
      user2: user2
    } do
      # Create a finished game
      game =
        GameState.new([
          {:user, user1.id, "alice"},
          {:user, user2.id, "bob"},
          {:ai, "AI-Easy", :easy}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["alice"])

      # Update player hands to simulate game end
      game = %{
        game
        | players: [
            %{Enum.at(game.players, 0) | hand: []},
            %{Enum.at(game.players, 1) | hand: [Card.new(:hearts, 5)]},
            %{Enum.at(game.players, 2) | hand: [Card.new(:spades, 10), Card.new(:clubs, 3)]}
          ]
      }

      # Save game first (for foreign key constraint)
      Games.save_game(game)

      assert :ok = Games.record_user_participation(game)

      # Check user_games records were created
      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 2

      # Verify alice (winner, position 0)
      alice_record = Enum.find(user_games, &(&1.user_id == user1.id))
      assert alice_record.position == 0
      assert alice_record.final_rank == 1

      # Verify bob (second place, position 1, 1 card left)
      bob_record = Enum.find(user_games, &(&1.user_id == user2.id))
      assert bob_record.position == 1
      assert bob_record.final_rank == 2
    end

    test "calculates ranks correctly for multiple winners", %{user1: user1, user2: user2} do
      game =
        GameState.new([
          {:user, user1.id, "alice"},
          {:user, user2.id, "bob"},
          {:anonymous, "Charlie"}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["alice", "bob"])

      # All players finished
      game = %{
        game
        | players: [
            %{Enum.at(game.players, 0) | hand: []},
            %{Enum.at(game.players, 1) | hand: []},
            %{Enum.at(game.players, 2) | hand: [Card.new(:hearts, 5)]}
          ]
      }

      Games.save_game(game)
      assert :ok = Games.record_user_participation(game)

      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 2

      alice_record = Enum.find(user_games, &(&1.user_id == user1.id))
      bob_record = Enum.find(user_games, &(&1.user_id == user2.id))

      # Alice finished first (rank 1)
      assert alice_record.final_rank == 1
      # Bob finished second (rank 2)
      assert bob_record.final_rank == 2
    end

    test "ranks non-winners by hand size", %{user1: user1, user2: user2, user3: user3} do
      game =
        GameState.new([
          {:user, user1.id, "alice"},
          {:user, user2.id, "bob"},
          {:user, user3.id, "charlie"}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [])

      # Nobody won yet, rank by hand size
      game = %{
        game
        | players: [
            %{Enum.at(game.players, 0) | hand: [Card.new(:hearts, 5), Card.new(:spades, 10)]},
            %{Enum.at(game.players, 1) | hand: [Card.new(:clubs, 3)]},
            %{
              Enum.at(game.players, 2)
              | hand: [Card.new(:diamonds, 7), Card.new(:hearts, 2), Card.new(:spades, 14)]
            }
          ]
      }

      Games.save_game(game)
      assert :ok = Games.record_user_participation(game)

      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 3

      alice_record = Enum.find(user_games, &(&1.user_id == user1.id))
      bob_record = Enum.find(user_games, &(&1.user_id == user2.id))
      charlie_record = Enum.find(user_games, &(&1.user_id == user3.id))

      # Bob has fewest cards (1) - rank 1
      assert bob_record.final_rank == 1
      # Alice has 2 cards - rank 2
      assert alice_record.final_rank == 2
      # Charlie has most cards (3) - rank 3
      assert charlie_record.final_rank == 3
    end

    test "does not record AI players", %{user1: user1} do
      game =
        GameState.new([
          {:user, user1.id, "alice"},
          {:ai, "AI-Easy", :easy},
          {:ai, "AI-Hard", :hard}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["alice"])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      assert :ok = Games.record_user_participation(game)

      # Only one user_game record (for alice)
      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 1
      assert hd(user_games).user_id == user1.id
    end

    test "does not record anonymous players", %{user1: user1} do
      game =
        GameState.new([
          {:user, user1.id, "alice"},
          {:anonymous, "Bob"},
          {:anonymous, "Charlie"}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["alice"])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      assert :ok = Games.record_user_participation(game)

      # Only one user_game record (for alice)
      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 1
      assert hd(user_games).user_id == user1.id
    end

    test "returns error for non-finished games", %{user1: user1} do
      game =
        GameState.new([{:user, user1.id, "alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()

      assert {:error, :game_not_finished} = Games.record_user_participation(game)

      # No records created
      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 0
    end

    test "handles duplicate inserts gracefully", %{user1: user1} do
      game =
        GameState.new([{:user, user1.id, "alice"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["alice"])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      # Record twice
      assert :ok = Games.record_user_participation(game)
      assert :ok = Games.record_user_participation(game)

      # Should only have one record (on_conflict: :nothing)
      user_games = Rachel.Repo.all(Rachel.Game.UserGame)
      assert length(user_games) == 1
    end
  end

  describe "list_user_games/2" do
    setup do
      {:ok, user} =
        Rachel.Accounts.register_user(%{
          email: "player@example.com",
          username: "player",
          password: "playerpassword1"
        })

      %{user: user}
    end

    test "returns empty list for user with no games", %{user: user} do
      assert [] = Games.list_user_games(user.id)
    end

    test "returns finished games for user", %{user: user} do
      # Create and record a finished game
      game =
        GameState.new([{:user, user.id, "player"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["player"])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      games = Games.list_user_games(user.id)
      assert length(games) == 1

      game_record = hd(games)
      assert game_record.id == game.id
      assert game_record.player_count == 2
      assert game_record.winners == ["player"]
      assert game_record.user_rank == 1
      assert game_record.user_position == 0
    end

    test "orders games by most recent first", %{user: user} do
      # Create older game
      old_game =
        GameState.new([{:user, user.id, "player"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["player"])
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -3600, :second))

      old_game = %{old_game | players: Enum.map(old_game.players, &%{&1 | hand: []})}

      # Create newer game
      new_game =
        GameState.new([{:user, user.id, "player"}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["player"])

      new_game = %{new_game | players: Enum.map(new_game.players, &%{&1 | hand: []})}

      Games.save_game(old_game)
      Games.record_user_participation(old_game)
      Games.save_game(new_game)
      Games.record_user_participation(new_game)

      games = Games.list_user_games(user.id)
      assert length(games) == 2

      # Newer game should be first
      assert hd(games).id == new_game.id
      assert Enum.at(games, 1).id == old_game.id
    end

    test "respects limit option", %{user: user} do
      # Create 5 games
      for _i <- 1..5 do
        game =
          GameState.new([{:user, user.id, "player"}, {:anonymous, "Bob"}])
          |> GameState.start_game()
          |> Map.put(:status, :finished)
          |> Map.put(:winners, ["player"])

        game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}
        Games.save_game(game)
        Games.record_user_participation(game)
      end

      # Default should return all 5
      all_games = Games.list_user_games(user.id)
      assert length(all_games) == 5

      # Limit to 3
      limited_games = Games.list_user_games(user.id, limit: 3)
      assert length(limited_games) == 3
    end

    test "does not include non-finished games", %{user: user} do
      # Create playing game
      playing_game =
        GameState.new([{:user, user.id, "player"}, {:anonymous, "Bob"}])
        |> GameState.start_game()

      Games.save_game(playing_game)

      # Should not appear in history
      games = Games.list_user_games(user.id)
      assert length(games) == 0
    end

    test "includes game metadata correctly", %{user: user} do
      game =
        GameState.new([
          {:user, user.id, "player"},
          {:anonymous, "Bob"},
          {:anonymous, "Charlie"}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["Bob"])
        |> Map.put(:turn_count, 42)

      # Player came in 2nd place (1 card left)
      game = %{
        game
        | players: [
            %{Enum.at(game.players, 0) | hand: [Card.new(:hearts, 5)]},
            %{Enum.at(game.players, 1) | hand: []},
            %{Enum.at(game.players, 2) | hand: [Card.new(:spades, 10), Card.new(:clubs, 3)]}
          ]
      }

      Games.save_game(game)
      Games.record_user_participation(game)

      [game_record] = Games.list_user_games(user.id)

      assert game_record.player_count == 3
      assert game_record.turn_count == 42
      assert game_record.winners == ["Bob"]
      assert game_record.user_rank == 2
      assert game_record.user_position == 0
      assert is_struct(game_record.finished_at, DateTime)
    end
  end
end
