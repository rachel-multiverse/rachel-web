defmodule Rachel.Benchmarks.GameBenchmark do
  @moduledoc """
  Performance benchmarks for game operations.

  These benchmarks measure the performance of core game operations to:
  - Establish performance baselines
  - Detect performance regressions
  - Identify optimization opportunities
  - Validate scalability

  Run with: `mix run lib/rachel/benchmarks/game_benchmark.ex`
  """

  # Suppress undefined module warning - Benchee is only available in :dev
  @compile {:no_warn_undefined, Benchee}

  alias Rachel.Game.{Deck, GameState}

  def run do
    IO.puts("\n=== Rachel Game Performance Benchmarks ===\n")

    Benchee.run(
      %{
        "game_creation_2_players" => fn ->
          GameState.new(["Player 1", "Player 2"])
        end,
        "game_creation_4_players" => fn ->
          GameState.new(["Player 1", "Player 2", "Player 3", "Player 4"])
        end,
        "game_creation_8_players" => fn ->
          GameState.new([
            "Player 1",
            "Player 2",
            "Player 3",
            "Player 4",
            "Player 5",
            "Player 6",
            "Player 7",
            "Player 8"
          ])
        end,
        "deck_shuffle" => fn ->
          Deck.new()
        end,
        "play_single_card" => fn {game, player_id, card} ->
          GameState.play_cards(game, player_id, [card], nil)
        end,
        "play_stack_of_3" => fn {game, player_id, cards} ->
          GameState.play_cards(game, player_id, cards, nil)
        end,
        "draw_cards" => fn {game, player_id} ->
          GameState.draw_cards(game, player_id, :cannot_play)
        end,
        "check_valid_play" => fn {game, card} ->
          Rachel.Game.Rules.can_play_card?(card, hd(game.discard_pile), game.nominated_suit)
        end
      },
      inputs: %{
        "Single card play" => setup_game_for_play(:single),
        "Stack play" => setup_game_for_play(:stack),
        "Draw operation" => setup_game_for_draw()
      },
      time: 5,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/results/game_benchmark.html"},
        Benchee.Formatters.Console
      ]
    )
  end

  defp setup_game_for_play(:single) do
    game = GameState.new(["Player 1", "Player 2"]) |> GameState.start_game()
    player = hd(game.players)
    # Find a valid card to play
    card = Enum.find(player.hand, fn c -> can_play?(c, game) end) || hd(player.hand)
    {game, player.id, card}
  end

  defp setup_game_for_play(:stack) do
    game = GameState.new(["Player 1", "Player 2"]) |> GameState.start_game()
    player = hd(game.players)
    # Find 3 cards of the same rank
    cards =
      player.hand
      |> Enum.group_by(& &1.rank)
      |> Enum.find_value(fn {_rank, cards} -> if length(cards) >= 3, do: Enum.take(cards, 3) end)

    cards = cards || Enum.take(player.hand, 3)
    {game, player.id, cards}
  end

  defp setup_game_for_draw do
    game = GameState.new(["Player 1", "Player 2"]) |> GameState.start_game()
    player = hd(game.players)
    {game, player.id}
  end

  defp can_play?(card, game) do
    Rachel.Game.Rules.can_play_card?(card, hd(game.discard_pile), game.nominated_suit)
  end
end

# Run benchmarks if this file is executed directly
if System.argv() == [] or "--run" in System.argv() do
  Rachel.Benchmarks.GameBenchmark.run()
end
