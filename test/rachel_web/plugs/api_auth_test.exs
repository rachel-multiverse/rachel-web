defmodule RachelWeb.Plugs.ApiAuthTest do
  use RachelWeb.ConnCase
  import Rachel.AccountsFixtures

  describe "API authentication" do
    test "accepts valid Bearer token", %{conn: conn} do
      user = user_fixture()
      token = Rachel.Accounts.generate_user_session_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/games")

      assert json_response(conn, 200)
      assert conn.assigns.current_user.id == user.id
    end

    test "rejects invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token_12345")
        |> get(~p"/api/games")

      assert json_response(conn, 401)
      assert json_response(conn, 401)["error"] == "Invalid or missing authorization token"
    end

    test "rejects missing authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/games")
      assert json_response(conn, 401)
    end

    test "rejects malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "InvalidFormat token123")
        |> get(~p"/api/games")

      assert json_response(conn, 401)
    end
  end
end
