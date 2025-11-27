defmodule Rachel.Leaderboard.IntegrationTest do
  use Rachel.DataCase, async: false

  alias Rachel.Game.Games
  alias Rachel.Game.GameState

  describe "game completion triggers rating update" do
    test "updates ratings for human players only" do
      user1 = insert_user()
      user2 = insert_user()

      # Create a mock finished game state with human players
      game_state = %GameState{
        id: Ecto.UUID.generate(),
        status: :finished,
        players: [
          %{
            id: "p1",
            name: "Player1",
            user_id: user1.id,
            type: :human,
            hand: [],
            status: :won,
            difficulty: nil
          },
          %{
            id: "p2",
            name: "Player2",
            user_id: user2.id,
            type: :human,
            hand: [],
            status: :playing,
            difficulty: nil
          },
          %{
            id: "ai",
            name: "AI",
            user_id: nil,
            type: :ai,
            hand: [],
            status: :playing,
            difficulty: :medium
          }
        ],
        winners: ["p1"],
        turn_count: 20,
        deck: [],
        discard_pile: [],
        current_player_index: 0,
        direction: :clockwise,
        pending_attack: nil,
        pending_skips: 0,
        nominated_suit: nil,
        created_at: DateTime.utc_now(),
        last_action_at: DateTime.utc_now(),
        deck_count: 1,
        expected_total_cards: 52
      }

      # Save the game to database first (required for foreign key constraint)
      {:ok, _} = Games.save_game(game_state)

      # Call the function that records participation (which should trigger rating update)
      Games.record_user_participation(game_state)

      # Allow async task to complete
      Process.sleep(100)

      # Verify ratings were updated for humans only
      updated_user1 = Rachel.Repo.get!(Rachel.Accounts.User, user1.id)
      updated_user2 = Rachel.Repo.get!(Rachel.Accounts.User, user2.id)

      # Winner should gain rating
      assert updated_user1.elo_rating > 1000
      assert updated_user1.elo_games_played == 1

      # Loser should lose rating
      assert updated_user2.elo_rating < 1000
      assert updated_user2.elo_games_played == 1
    end

    test "does not update ratings for AI-only games" do
      user = insert_user()

      game_state = %GameState{
        id: Ecto.UUID.generate(),
        status: :finished,
        players: [
          %{
            id: "p1",
            name: "Player1",
            user_id: user.id,
            type: :human,
            hand: [],
            status: :won,
            difficulty: nil
          },
          %{
            id: "ai1",
            name: "AI1",
            user_id: nil,
            type: :ai,
            hand: [],
            status: :playing,
            difficulty: :medium
          },
          %{
            id: "ai2",
            name: "AI2",
            user_id: nil,
            type: :ai,
            hand: [],
            status: :playing,
            difficulty: :medium
          }
        ],
        winners: ["p1"],
        turn_count: 15,
        deck: [],
        discard_pile: [],
        current_player_index: 0,
        direction: :clockwise,
        pending_attack: nil,
        pending_skips: 0,
        nominated_suit: nil,
        created_at: DateTime.utc_now(),
        last_action_at: DateTime.utc_now(),
        deck_count: 1,
        expected_total_cards: 52
      }

      # Save the game to database first (required for foreign key constraint)
      {:ok, _} = Games.save_game(game_state)

      Games.record_user_participation(game_state)
      Process.sleep(100)

      # User rating should not change (only 1 human)
      updated_user = Rachel.Repo.get!(Rachel.Accounts.User, user.id)
      assert updated_user.elo_rating == 1000
      assert updated_user.elo_games_played == 0
    end
  end

  defp insert_user do
    {:ok, user} =
      %Rachel.Accounts.User{}
      |> Rachel.Accounts.User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Rachel.Repo.insert()

    user
  end
end
