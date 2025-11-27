defmodule RachelWeb.LeaderboardLiveTest do
  use RachelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount" do
    test "renders leaderboard page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Leaderboard"
      assert html =~ "Rank"
      assert html =~ "Player"
      assert html =~ "Rating"
    end

    test "shows tier legend", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Bronze"
      assert html =~ "Silver"
      assert html =~ "Gold"
      assert html =~ "Platinum"
      assert html =~ "Diamond"
    end

    test "shows current user's rank when they have games", %{conn: conn, user: user} do
      # Give user some ranked games
      user
      |> Ecto.Changeset.change(%{elo_rating: 1150, elo_games_played: 10, elo_tier: "gold"})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Your Rank"
      assert html =~ "1150"
      assert html =~ "Gold"
    end

    test "shows players in order by rating", %{conn: conn} do
      # Create users with different ratings
      for {rating, name} <- [{1300, "TopPlayer"}, {1100, "MidPlayer"}, {900, "LowPlayer"}] do
        {:ok, u} =
          %Rachel.Accounts.User{}
          |> Rachel.Accounts.User.registration_changeset(%{
            email: "#{name}@test.com",
            username: name,
            password: "password123456"
          })
          |> Rachel.Repo.insert()

        u
        |> Ecto.Changeset.change(%{
          elo_rating: rating,
          elo_games_played: 5,
          elo_tier: Rachel.Leaderboard.calculate_tier(rating)
        })
        |> Rachel.Repo.update!()
      end

      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      # TopPlayer should appear before MidPlayer
      assert String.contains?(html, "TopPlayer")
      top_pos = :binary.match(html, "TopPlayer") |> elem(0)
      mid_pos = :binary.match(html, "MidPlayer") |> elem(0)
      assert top_pos < mid_pos
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      unauth_conn = build_conn()
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(unauth_conn, ~p"/leaderboard")
    end
  end
end
