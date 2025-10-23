defmodule RachelWeb.StatsLiveTest do
  use RachelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount" do
    test "renders statistics page for user with games", %{conn: conn, user: user} do
      # Update user stats
      user
      |> Ecto.Changeset.change(%{
        games_played: 10,
        games_won: 6,
        total_turns: 150
      })
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Statistics"
      assert html =~ "Games Played"
      assert html =~ "10"
      assert html =~ "Games Won"
      assert html =~ "6"
      assert html =~ "Win Rate"
      assert html =~ "60.0%"
      assert html =~ "Total Turns"
      assert html =~ "150"
    end

    test "renders statistics page for user with no games", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Statistics"
      assert html =~ "Games Played"
      assert html =~ "0"
      assert html =~ "Win Rate"
      assert html =~ "0.0%"
      assert html =~ "Ready to Start Your Journey?"
    end

    test "calculates win rate correctly", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{
        games_played: 20,
        games_won: 15
      })
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # Win rate should be 75.0%
      assert html =~ "75.0%"
    end

    test "calculates average turns per game correctly", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{
        games_played: 10,
        total_turns: 125
      })
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # Avg turns should be 12.5
      assert html =~ "12.5"
    end

    test "handles zero division for win rate gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      # Should show 0.0% for zero games
      assert html =~ "0.0%"
    end

    test "displays loss count correctly", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{
        games_played: 10,
        games_won: 3
      })
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # Should show 3W - 7L
      assert html =~ "3W - 7L"
    end

    test "displays username in header", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      # HTML escapes apostrophe as &#39;
      assert html =~ "#{user.username}&#39;s Statistics"
    end

    test "displays member since date", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      expected_date = Calendar.strftime(user.inserted_at, "%B %Y")
      assert html =~ expected_date
    end
  end

  describe "experience_level/1 helper" do
    test "returns correct level for Expert (100+ games)", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 150})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Expert 🏆"
    end

    test "returns correct level for Veteran (50-99 games)", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 75})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Veteran ⭐"
    end

    test "returns correct level for Experienced (25-49 games)", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 35})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Experienced 💪"
    end

    test "returns correct level for Regular (10-24 games)", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 15})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Regular 🎮"
    end

    test "returns correct level for Beginner (5-9 games)", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 7})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Beginner 🌱"
    end

    test "returns correct level for Newbie (0-4 games)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Newbie 🐣"
    end
  end

  describe "win_rank/1 helper" do
    test "returns Master for 70%+ win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 8})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 80% win rate
      assert html =~ "Master 🥇"
    end

    test "returns Pro for 60-69% win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 6})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 60% win rate
      assert html =~ "Pro 🥈"
    end

    test "returns Skilled for 50-59% win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 5})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 50% win rate
      assert html =~ "Skilled 🥉"
    end

    test "returns Average for 40-49% win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 4})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 40% win rate
      assert html =~ "Average 📊"
    end

    test "returns Learning for 30-39% win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 3})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 30% win rate
      assert html =~ "Learning 📚"
    end

    test "returns Rookie for <30% win rate", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 2})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # 20% win rate
      assert html =~ "Rookie 🎓"
    end
  end

  describe "UI elements" do
    test "includes navigation link to lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ ~s(href="/lobby")
      assert html =~ "Play Now"
    end

    test "shows performance overview section", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 6})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Performance Overview"
      assert html =~ "Wins vs Losses"
    end

    test "shows quick facts section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Quick Facts"
      assert html =~ "Experience Level"
      assert html =~ "Win Rank"
      assert html =~ "Member Since"
    end

    test "shows call to action for new players", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/stats")

      assert html =~ "Ready to Start Your Journey?"
      assert html =~ "Play your first game"
    end

    test "hides call to action for players with games", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 1})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      refute html =~ "Ready to Start Your Journey?"
    end

    test "displays win rate progress bar with correct width", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(%{games_played: 10, games_won: 6})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/stats")

      # Should have inline style with 60% width
      assert html =~ "width: 60.0%"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      # Create new connection without auth
      unauth_conn = build_conn()

      # Should redirect to login
      assert {:error, {:redirect, %{to: path}}} = live(unauth_conn, ~p"/stats")
      assert path == "/users/log-in"
    end
  end
end
