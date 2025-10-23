defmodule RachelWeb.HistoryLiveTest do
  use RachelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rachel.Game.{Card, Games, GameState}

  setup :register_and_log_in_user

  describe "mount" do
    test "renders empty state when user has no games", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "Game History"
      assert html =~ "No Game History Yet"
      assert html =~ "Start playing to build your game history!"
    end

    test "renders game list when user has games", %{conn: conn, user: user} do
      # Create a finished game
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "Game History"
      assert html =~ "Victory"
      assert html =~ user.username
      assert html =~ "Bob"
    end

    test "shows correct victory badge for winning games", %{conn: conn, user: user} do
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Opponent"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "🏆 Victory"
    end

    test "shows correct placement badge for losing games", %{conn: conn, user: user} do
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Winner"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, ["Winner"])

      # User has 1 card left, came in 2nd
      game = %{
        game
        | players: [
            %{Enum.at(game.players, 0) | hand: [Card.new(:hearts, 5)]},
            %{Enum.at(game.players, 1) | hand: []}
          ]
      }

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "2nd Place"
    end

    test "displays player names correctly", %{conn: conn, user: user} do
      game =
        GameState.new([
          {:user, user.id, user.username},
          {:anonymous, "Alice"},
          {:anonymous, "Bob"}
        ])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ user.username
      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "shows crown icon for winners", %{conn: conn, user: user} do
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "👑"
    end

    test "displays game statistics correctly", %{conn: conn, user: user} do
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])
        |> Map.put(:turn_count, 25)

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "2 Players"
      assert html =~ "Total Turns:"
      assert html =~ "25"
      assert html =~ "1st"
    end

    test "orders games by most recent first", %{conn: conn, user: user} do
      # Create older game
      old_game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -7200, :second))

      old_game = %{old_game | players: Enum.map(old_game.players, &%{&1 | hand: []})}

      # Create newer game
      new_game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])

      new_game = %{new_game | players: Enum.map(new_game.players, &%{&1 | hand: []})}

      Games.save_game(old_game)
      Games.record_user_participation(old_game)
      Games.save_game(new_game)
      Games.record_user_participation(new_game)

      {:ok, _view, html} = live(conn, ~p"/history")

      # Both games should be present
      assert html =~ String.slice(new_game.id, 0..7)
      assert html =~ String.slice(old_game.id, 0..7)

      # Newer game should appear first (before older game in HTML)
      new_game_position = :binary.match(html, String.slice(new_game.id, 0..7)) |> elem(0)
      old_game_position = :binary.match(html, String.slice(old_game.id, 0..7)) |> elem(0)
      assert new_game_position < old_game_position
    end

    test "shows limit message when displaying 50 games", %{conn: conn, user: user} do
      # Create 50 games
      for _i <- 1..50 do
        game =
          GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
          |> GameState.start_game()
          |> Map.put(:status, :finished)
          |> Map.put(:winners, [user.username])

        game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}
        Games.save_game(game)
        Games.record_user_participation(game)
      end

      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "Showing your 50 most recent games"
    end

    test "does not show limit message for fewer than 50 games", %{conn: conn, user: user} do
      # Create 10 games
      for _i <- 1..10 do
        game =
          GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
          |> GameState.start_game()
          |> Map.put(:status, :finished)
          |> Map.put(:winners, [user.username])

        game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}
        Games.save_game(game)
        Games.record_user_participation(game)
      end

      {:ok, _view, html} = live(conn, ~p"/history")

      refute html =~ "Showing your 50 most recent games"
    end
  end

  describe "navigation" do
    test "includes links to stats and lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/history")

      assert html =~ "View Stats"
      assert html =~ "Play Now"
    end

    test "stats link navigates correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/history")

      # Check link exists with correct href
      assert html =~ ~s(href="/stats")
      assert html =~ "View Stats"
    end

    test "lobby link navigates correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/history")

      # Check link exists with correct href
      html = render(view)
      assert html =~ ~s(href="/lobby")
    end
  end

  describe "ordinal/1 helper" do
    test "formats ordinal numbers correctly", %{conn: conn, user: user} do
      # Create games with user at different positions to test ordinal formatting
      # The ordinal/1 helper formats numbers like: 1st, 2nd, 3rd, 4th, 11th, 12th, 13th
      # We'll test positions 1-8 (game supports max 8 players) which covers the key cases:
      # - 1st (ends in 1, not 11)
      # - 2nd (ends in 2, not 12)
      # - 3rd (ends in 3, not 13)
      # - 4th-8th (all use "th")

      # Create 8 games with user at each position (0-7 in array = 1st-8th displayed)
      for position <- 0..7 do
        # Build player list with user at the specified position
        all_players = [
          {:user, user.id, user.username},
          {:anonymous, "Player2"},
          {:anonymous, "Player3"},
          {:anonymous, "Player4"},
          {:anonymous, "Player5"},
          {:anonymous, "Player6"},
          {:anonymous, "Player7"},
          {:anonymous, "Player8"}
        ]

        # Rotate players so user is at desired position
        players = Enum.drop(all_players, position) ++ Enum.take(all_players, position)

        game =
          GameState.new(players)
          |> GameState.start_game()
          |> Map.put(:status, :finished)
          |> Map.put(:winners, ["Player2"])

        game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

        Games.save_game(game)
        Games.record_user_participation(game)
      end

      {:ok, _view, html} = live(conn, ~p"/history")

      # Check various ordinals appear correctly in Position stat
      assert html =~ "1st"
      assert html =~ "2nd"
      assert html =~ "3rd"
      assert html =~ "4th"
      assert html =~ "5th"
      assert html =~ "6th"
      assert html =~ "7th"
      assert html =~ "8th"
    end
  end

  describe "relative_time/1 helper" do
    test "shows recent timestamps correctly", %{conn: conn, user: user} do
      # Create game from 2 hours ago
      game =
        GameState.new([{:user, user.id, user.username}, {:anonymous, "Bob"}])
        |> GameState.start_game()
        |> Map.put(:status, :finished)
        |> Map.put(:winners, [user.username])
        |> Map.put(:last_action_at, DateTime.add(DateTime.utc_now(), -7200, :second))

      game = %{game | players: Enum.map(game.players, &%{&1 | hand: []})}

      Games.save_game(game)
      Games.record_user_participation(game)

      {:ok, _view, html} = live(conn, ~p"/history")

      # Should show "2h ago"
      assert html =~ "2h ago"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      # Create new connection without auth
      unauth_conn = build_conn()

      # Should redirect to login
      assert {:error, {:redirect, %{to: path}}} = live(unauth_conn, ~p"/history")
      assert path == "/users/log-in"
    end
  end
end
