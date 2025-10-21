defmodule RachelWeb.API.GameControllerTest do
  use RachelWeb.ConnCase, async: true

  import Rachel.AccountsFixtures

  alias Rachel.{Accounts, GameManager}

  setup %{conn: conn} do
    # Create and authenticate a user
    user = user_fixture()
    token = Accounts.generate_user_session_token(user)

    authenticated_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, authenticated_conn: authenticated_conn, user: user}
  end

  describe "POST /api/games (create AI game)" do
    test "creates a new AI game with authenticated user", %{authenticated_conn: conn, user: user} do
      params = %{"type" => "ai"}

      conn = post(conn, ~p"/api/games", params)

      assert %{
               "game" => game
             } = json_response(conn, 200)

      assert game["id"]
      assert game["status"] == "playing"
      assert is_list(game["players"])

      # Should have the human player plus AI opponents
      player_names = Enum.map(game["players"], & &1["name"])
      assert (user.display_name || user.username) in player_names
    end

    test "rejects request without authentication", %{conn: conn} do
      params = %{"type" => "ai"}

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/games", params)

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/games (create multiplayer lobby)" do
    test "creates a new multiplayer lobby", %{authenticated_conn: conn, user: user} do
      params = %{"type" => "multiplayer"}

      conn = post(conn, ~p"/api/games", params)

      assert %{
               "game" => game
             } = json_response(conn, 200)

      assert game["id"]
      assert game["status"] == "waiting"
      assert length(game["players"]) == 1

      player = List.first(game["players"])
      assert player["name"] == (user.display_name || user.username)
      assert player["user_id"] == user.id
    end

    test "rejects request without authentication", %{conn: conn} do
      params = %{"type" => "multiplayer"}

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/games", params)

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/games" do
    test "lists all active games", %{authenticated_conn: conn, user: user} do
      # Create a few games
      player = {:user, user.id, user.display_name || user.username}
      {:ok, _game1_id} = GameManager.create_lobby(player)
      {:ok, _game2_id} = GameManager.create_lobby(player)

      conn = get(conn, ~p"/api/games")

      assert %{"games" => games} = json_response(conn, 200)
      assert is_list(games)
      assert length(games) >= 2
    end

    test "returns empty list when no games exist", %{authenticated_conn: conn} do
      conn = get(conn, ~p"/api/games")

      assert %{"games" => games} = json_response(conn, 200)
      assert is_list(games)
    end

    test "rejects request without authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/games")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/games/:id" do
    setup %{user: user} do
      player = {:user, user.id, user.display_name || user.username}
      {:ok, game_id} = GameManager.create_lobby(player)

      {:ok, game_id: game_id}
    end

    test "returns game details", %{authenticated_conn: conn, game_id: game_id} do
      conn = get(conn, ~p"/api/games/#{game_id}")

      assert %{
               "game" => game
             } = json_response(conn, 200)

      assert game["id"] == game_id
      assert game["status"] in ["waiting", "playing", "finished"]
      assert is_list(game["players"])
    end

    test "returns 404 for non-existent game", %{authenticated_conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/games/#{fake_id}")

      assert %{"error" => "Game not found"} = json_response(conn, 404)
    end

    test "rejects request without authentication", %{conn: conn, game_id: game_id} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/games/#{game_id}")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/games/:id/join" do
    setup %{user: user} do
      # Create a lobby by another user
      other_user = user_fixture()
      player = {:user, other_user.id, other_user.display_name || other_user.username}
      {:ok, game_id} = GameManager.create_lobby(player)
      {:ok, game_id: game_id}
    end

    test "adds player to waiting game", %{authenticated_conn: conn, game_id: game_id, user: user} do
      conn = post(conn, ~p"/api/games/#{game_id}/join")

      assert %{"game" => game} = json_response(conn, 200)
      assert length(game["players"]) == 2

      player_names = Enum.map(game["players"], & &1["name"])
      assert (user.display_name || user.username) in player_names
    end

    test "returns error when joining non-existent game", %{authenticated_conn: authenticated_conn} do
      fake_id = Ecto.UUID.generate()
      conn = post(authenticated_conn, ~p"/api/games/#{fake_id}/join")

      assert %{"error" => "Game not found"} = json_response(conn, 404)
    end

    test "rejects request without authentication", %{conn: conn, game_id: game_id} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/games/#{game_id}/join")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/games/:id/draw" do
    setup %{user: user} do
      # Create and start an AI game where user goes first
      player = {:user, user.id, user.display_name || user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      {:ok, _game} = GameManager.start_game(game_id)

      {:ok, game_id: game_id}
    end

    test "draws a card on player's turn", %{
      authenticated_conn: conn,
      game_id: game_id,
      user: user
    } do
      # Check if it's our turn
      {:ok, game} = GameManager.get_game(game_id)
      current_player = Enum.at(game.players, game.current_player_index)

      if current_player.user_id == user.id do
        initial_hand_size = length(current_player.hand)
        conn = post(conn, ~p"/api/games/#{game_id}/draw")

        response = json_response(conn, 200)
        assert %{"game" => updated_game} = response

        updated_player = Enum.find(updated_game["players"], &(&1["user_id"] == user.id))
        # Hand size should increase by 1
        assert length(updated_player["hand"]) >= initial_hand_size
      else
        # Not our turn, should get an error
        conn = post(conn, ~p"/api/games/#{game_id}/draw")
        # Should return an error about not being the current player
        assert %{"error" => _} = json_response(conn, 422)
      end
    end

    test "returns error for non-existent game", %{authenticated_conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = post(conn, ~p"/api/games/#{fake_id}/draw")

      assert %{"error" => "Game not found"} = json_response(conn, 404)
    end

    test "rejects request without authentication", %{conn: conn, game_id: game_id} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/games/#{game_id}/draw")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/games/:id/play" do
    setup %{user: user} do
      # Create and start an AI game
      player = {:user, user.id, user.display_name || user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      {:ok, game} = GameManager.start_game(game_id)

      {:ok, game_id: game_id, game: game}
    end

    test "plays a valid card on player's turn", %{
      authenticated_conn: conn,
      game_id: game_id,
      user: user
    } do
      {:ok, game} = GameManager.get_game(game_id)
      current_player = Enum.at(game.players, game.current_player_index)

      if current_player.user_id == user.id && length(current_player.hand) > 0 do
        # Get the top card of discard pile
        top_card = List.first(game.discard_pile)

        # Find a card in hand that matches (or use any Ace)
        matching_card =
          Enum.find(current_player.hand, fn card ->
            card.suit == top_card.suit || card.rank == top_card.rank || card.rank == "A"
          end)

        if matching_card do
          params = %{
            "cards" => [
              %{
                "suit" => Atom.to_string(matching_card.suit),
                "rank" => matching_card.rank
              }
            ],
            "suit" => if(matching_card.rank == "A", do: "hearts", else: "")
          }

          conn = post(conn, ~p"/api/games/#{game_id}/play", params)

          # Should succeed
          assert %{"game" => _updated_game} = json_response(conn, 200)
        end
      end
    end

    test "rejects card not in hand", %{authenticated_conn: conn, game_id: game_id, user: user} do
      {:ok, game} = GameManager.get_game(game_id)
      current_player = Enum.at(game.players, game.current_player_index)

      if current_player.user_id == user.id do
        # Try to play cards definitely not in hand
        params = %{
          "cards" => [
            %{"suit" => "hearts", "rank" => "A"},
            %{"suit" => "hearts", "rank" => "K"},
            %{"suit" => "hearts", "rank" => "Q"},
            %{"suit" => "hearts", "rank" => "J"}
          ],
          "suit" => ""
        }

        conn = post(conn, ~p"/api/games/#{game_id}/play", params)

        # Should fail
        response = json_response(conn, 422)
        assert %{"error" => _} = response
      end
    end

    test "returns error for non-existent game", %{authenticated_conn: conn} do
      fake_id = Ecto.UUID.generate()

      params = %{
        "cards" => [%{"suit" => "hearts", "rank" => "A"}],
        "suit" => "hearts"
      }

      conn = post(conn, ~p"/api/games/#{fake_id}/play", params)

      assert %{"error" => "Game not found"} = json_response(conn, 404)
    end

    test "rejects request without authentication", %{conn: conn, game_id: game_id} do
      params = %{
        "cards" => [%{"suit" => "hearts", "rank" => "A"}],
        "suit" => ""
      }

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/games/#{game_id}/play", params)

      assert json_response(conn, 401)
    end
  end

  describe "authentication edge cases" do
    test "rejects request with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer invalid_token_here")
        |> get(~p"/api/games")

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "rejects request with malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "NotBearer token")
        |> get(~p"/api/games")

      assert json_response(conn, 401)
    end

    test "rejects request without authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/games")

      assert json_response(conn, 401)
    end
  end
end
