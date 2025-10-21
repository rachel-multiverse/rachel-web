defmodule RachelWeb.API.AuthControllerTest do
  use RachelWeb.ConnCase, async: true

  import Rachel.AccountsFixtures

  alias Rachel.Accounts

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")
    {:ok, conn: conn}
  end

  describe "POST /api/auth/register" do
    test "creates user and returns token with valid data", %{conn: conn} do
      user_params = %{
        "user" => %{
          "email" => "newuser@example.com",
          "password" => "password123456",
          "username" => "newuser"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{
               "user" => user,
               "token" => token
             } = json_response(conn, 201)

      assert user["email"] == "newuser@example.com"
      assert user["username"] == "newuser"
      assert is_binary(token)
      assert String.length(token) > 0

      # Verify user was actually created
      assert Accounts.get_user_by_email("newuser@example.com")
    end

    test "returns error with invalid email", %{conn: conn} do
      user_params = %{
        "user" => %{
          "email" => "not_an_email",
          "password" => "password123456",
          "username" => "testuser"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email")
    end

    test "returns error with short password", %{conn: conn} do
      user_params = %{
        "user" => %{
          "email" => "test@example.com",
          "password" => "short",
          "username" => "testuser"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "password")
    end

    test "returns error with duplicate email", %{conn: conn} do
      # Create a user first
      existing_user = user_fixture()

      user_params = %{
        "user" => %{
          "email" => existing_user.email,
          "password" => "password123456",
          "username" => "differentusername"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email")
    end

    test "returns error with missing username", %{conn: conn} do
      user_params = %{
        "user" => %{
          "email" => "test@example.com",
          "password" => "password123456"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "username")
    end

    test "returns error with duplicate username", %{conn: conn} do
      existing_user = user_fixture()

      user_params = %{
        "user" => %{
          "email" => "different@example.com",
          "password" => "password123456",
          "username" => existing_user.username
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "username")
    end

    test "returns error with empty password", %{conn: conn} do
      user_params = %{
        "user" => %{
          "email" => "test@example.com",
          "password" => "",
          "username" => "testuser"
        }
      }

      conn = post(conn, ~p"/api/auth/register", user_params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "password")
    end
  end

  describe "POST /api/auth/login" do
    setup do
      user = user_fixture()
      {:ok, user: user}
    end

    test "returns user and token with valid credentials", %{conn: conn, user: user} do
      login_params = %{
        "email" => user.email,
        "password" => valid_user_password()
      }

      conn = post(conn, ~p"/api/auth/login", login_params)

      assert %{
               "user" => returned_user,
               "token" => token
             } = json_response(conn, 200)

      assert returned_user["id"] == user.id
      assert returned_user["email"] == user.email
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "marks user as online after login", %{conn: conn, user: user} do
      login_params = %{
        "email" => user.email,
        "password" => valid_user_password()
      }

      conn = post(conn, ~p"/api/auth/login", login_params)

      assert %{"user" => returned_user} = json_response(conn, 200)
      assert returned_user["is_online"] == true

      # Verify in database
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.is_online == true
    end

    test "returns error with invalid email", %{conn: conn} do
      login_params = %{
        "email" => "nonexistent@example.com",
        "password" => "somepassword"
      }

      conn = post(conn, ~p"/api/auth/login", login_params)

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end

    test "returns error with invalid password", %{conn: conn, user: user} do
      login_params = %{
        "email" => user.email,
        "password" => "wrongpassword"
      }

      conn = post(conn, ~p"/api/auth/login", login_params)

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end

    test "returns error with missing email", %{conn: conn} do
      login_params = %{"password" => "somepassword"}

      assert_error_sent 400, fn ->
        post(conn, ~p"/api/auth/login", login_params)
      end
    end

    test "returns error with missing password", %{conn: conn, user: user} do
      login_params = %{"email" => user.email}

      assert_error_sent 400, fn ->
        post(conn, ~p"/api/auth/login", login_params)
      end
    end

    test "returned token can be used for authentication", %{conn: conn, user: user} do
      # First login
      login_params = %{
        "email" => user.email,
        "password" => valid_user_password()
      }

      conn = post(conn, ~p"/api/auth/login", login_params)
      assert %{"token" => token} = json_response(conn, 200)

      # Use the token to access a protected endpoint
      # Use the token directly (not base64-encoded)
      authenticated_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      assert %{"user" => returned_user} = json_response(authenticated_conn, 200)
      assert returned_user["id"] == user.id
    end
  end

  describe "GET /api/auth/me" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      authenticated_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: authenticated_conn, user: user}
    end

    test "returns current user with valid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => returned_user} = json_response(conn, 200)
      assert returned_user["id"] == user.id
      assert returned_user["email"] == user.email
      assert returned_user["username"] == user.username
    end

    test "returns user stats", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)
      assert Map.has_key?(user, "games_played")
      assert Map.has_key?(user, "games_won")
      assert Map.has_key?(user, "total_turns")
    end

    test "returns user preferences", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)
      assert Map.has_key?(user, "preferences")
      assert is_map(user["preferences"])
    end

    test "returns error without authentication" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 401)
    end

    test "returns error with invalid token" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer invalid_token")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/auth/logout" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Mark user as online first
      Accounts.user_online(user)

      authenticated_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: authenticated_conn, user: user}
    end

    test "marks user as offline", %{conn: conn, user: user} do
      # Verify user is online
      online_user = Accounts.get_user!(user.id)
      assert online_user.is_online == true

      conn = post(conn, ~p"/api/auth/logout")

      assert %{"message" => "Logged out successfully"} = json_response(conn, 200)

      # Verify user is now offline
      offline_user = Accounts.get_user!(user.id)
      assert offline_user.is_online == false
    end

    test "returns success message", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout")

      assert %{"message" => message} = json_response(conn, 200)
      assert message =~ "Logged out"
    end

    test "requires authentication" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/auth/logout")

      assert json_response(conn, 401)
    end
  end

  describe "user JSON structure" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      authenticated_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      {:ok, conn: authenticated_conn}
    end

    test "includes all expected fields", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)

      # Verify all expected fields are present
      assert Map.has_key?(user, "id")
      assert Map.has_key?(user, "email")
      assert Map.has_key?(user, "username")
      assert Map.has_key?(user, "display_name")
      assert Map.has_key?(user, "avatar_url")
      assert Map.has_key?(user, "games_played")
      assert Map.has_key?(user, "games_won")
      assert Map.has_key?(user, "total_turns")
      assert Map.has_key?(user, "is_online")
      assert Map.has_key?(user, "preferences")
    end

    test "does not include sensitive fields", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)

      # Verify password and hashed password are NOT included
      refute Map.has_key?(user, "password")
      refute Map.has_key?(user, "hashed_password")
    end

    test "display_name defaults to username when not set", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)
      # If display_name is nil, it should return username
      assert user["display_name"] == user["username"]
    end
  end
end
