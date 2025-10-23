defmodule RachelWeb.GameLive.GameOverModalTest do
  use RachelWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RachelWeb.GameLive.GameOverModal
  alias Rachel.Game.Card

  describe "render/1" do
    test "displays game over message" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 15,
        players: [
          %{id: 0, name: "Alice", hand: []},
          %{id: 1, name: "Bob", hand: [%Card{suit: :hearts, rank: 5}]}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "Game Over!"
      assert html =~ "Alice Wins!"
      assert html =~ "🏆"
    end

    test "displays final statistics" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 25,
        players: [
          %{id: 0, name: "Player1", hand: []},
          %{id: 1, name: "Player2", hand: [%Card{suit: :clubs, rank: 3}]}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "Total Turns:"
      assert html =~ "25"
      assert html =~ "Players:"
      assert html =~ "2"
    end

    test "displays final standings" do
      game = %{
        status: :finished,
        winners: [1],
        turn_count: 20,
        players: [
          %{id: 0, name: "Alice", hand: [%Card{suit: :hearts, rank: 5}]},
          %{id: 1, name: "Bob", hand: []},
          %{id: 2, name: "Charlie", hand: [%Card{suit: :spades, rank: 7}, %Card{suit: :clubs, rank: 2}]}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "Final Standings:"
      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Charlie"
      assert html =~ "1 cards left"
      assert html =~ "0 cards left"
      assert html =~ "2 cards left"
    end

    test "shows play again button" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 10,
        players: [
          %{id: 0, name: "Winner", hand: []}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "Play Again"
      assert html =~ "phx-click=\"new_game\""
    end

    test "shows back to lobby link" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 10,
        players: [
          %{id: 0, name: "Winner", hand: []}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "Back to Lobby"
      assert html =~ "href=\"/\""
    end

    test "includes confetti animation" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 10,
        players: [
          %{id: 0, name: "Winner", hand: []}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "confetti-fall"
    end

    test "includes victory sound hook" do
      game = %{
        status: :finished,
        winners: [0],
        turn_count: 10,
        players: [
          %{id: 0, name: "Winner", hand: []}
        ]
      }

      html =
        render_component(GameOverModal,
          id: "game-over",
          game: game
        )

      assert html =~ "victory-sound"
      assert html =~ "phx-hook=\"VictorySound\""
    end
  end
end
