defmodule Rachel.Benchmarks.LoadTest do
  @moduledoc """
  Load testing suite for concurrent game operations.

  Simulates realistic load scenarios to measure:
  - System throughput under load
  - Response time degradation
  - Resource consumption patterns
  - Maximum concurrent games supported
  - Breaking points and failure modes

  Run with: `mix run lib/rachel/benchmarks/load_test.ex`
  """

  require Logger
  alias Rachel.Game.GameSupervisor

  @doc """
  Run the load test suite.
  """
  def run do
    IO.puts("\n=== Rachel Load Testing Suite ===\n")

    # Start with light load and progressively increase
    scenarios = [
      {10, "Light load (10 concurrent games)"},
      {50, "Moderate load (50 concurrent games)"},
      {100, "Heavy load (100 concurrent games)"},
      {200, "Stress test (200 concurrent games)"},
      {500, "Breaking point test (500 concurrent games)"}
    ]

    results =
      Enum.map(scenarios, fn {num_games, description} ->
        IO.puts("\n--- #{description} ---")
        run_scenario(num_games)
      end)

    print_summary(results)
  end

  defp run_scenario(num_games) do
    start_time = System.monotonic_time(:millisecond)

    # Create games concurrently
    tasks =
      for i <- 1..num_games do
        Task.async(fn ->
          create_and_play_game(i)
        end)
      end

    # Wait for all games to complete with timeout
    results = Task.await_many(tasks, 60_000)

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.count(results, &match?({:error, _}, &1))

    success_times =
      Enum.flat_map(results, fn
        {:ok, time} -> [time]
        _ -> []
      end)

    avg_time =
      if length(success_times) > 0, do: Enum.sum(success_times) / length(success_times), else: 0.0

    min_time = if length(success_times) > 0, do: Enum.min(success_times), else: 0
    max_time = if length(success_times) > 0, do: Enum.max(success_times), else: 0

    # Get p95 time
    p95_time =
      if length(success_times) > 0 do
        sorted = Enum.sort(success_times)
        p95_index = floor(length(sorted) * 0.95)
        Enum.at(sorted, p95_index) || 0
      else
        0
      end

    result = %{
      num_games: num_games,
      duration: duration,
      successes: successes,
      failures: failures,
      avg_time: avg_time,
      min_time: min_time,
      max_time: max_time,
      p95_time: p95_time,
      throughput: if(duration > 0, do: successes / (duration / 1000), else: 0.0)
    }

    print_result(result)
    cleanup_games()

    result
  end

  defp create_and_play_game(game_num) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Create game
      players = ["AI Player 1", "AI Player 2", "AI Player 3", "AI Player 4"]
      {:ok, game_id} = GameSupervisor.start_game(players, "load-test-#{game_num}")

      # Start game
      Rachel.GameManager.get_game(game_id)
      |> case do
        {:ok, _game} ->
          # Simulate a few turns
          simulate_turns(game_id, 5)
          end_time = System.monotonic_time(:millisecond)
          {:ok, end_time - start_time}

        {:error, reason} ->
          {:error, reason}
      end
    catch
      kind, reason ->
        Logger.error("Game #{game_num} failed: #{inspect({kind, reason})}")
        {:error, {kind, reason}}
    end
  end

  defp simulate_turns(_game_id, 0), do: :ok

  defp simulate_turns(game_id, turns_remaining) do
    case Rachel.GameManager.get_game(game_id) do
      {:ok, game} ->
        if game.status == :playing do
          current_player = Enum.at(game.players, game.current_player_index)

          # Try to play a card or draw
          case try_play_or_draw(game, current_player) do
            :ok -> simulate_turns(game_id, turns_remaining - 1)
            :error -> :ok
          end
        else
          :ok
        end

      {:error, _} ->
        :ok
    end
  end

  defp try_play_or_draw(game, player) do
    # Find a valid card to play
    valid_card =
      Enum.find(player.hand, fn card ->
        Rachel.Game.Rules.can_play_card?(card, hd(game.discard_pile), game.nominated_suit)
      end)

    case valid_card do
      nil ->
        # Draw a card
        Rachel.GameManager.draw_cards(game.id, player.id, :cannot_play)
        :ok

      card ->
        # Play the card
        Rachel.GameManager.play_cards(game.id, player.id, [card], nil)
        :ok
    end
  catch
    _, _ -> :error
  end

  defp cleanup_games do
    # Give games time to clean up naturally
    Process.sleep(100)

    # Force cleanup any remaining games
    try do
      GameSupervisor.list_games()
      |> Enum.each(fn game_id ->
        if String.starts_with?(game_id, "load-test-") do
          try do
            GameSupervisor.stop_game(game_id)
          catch
            _, _ -> :ok
          end
        end
      end)
    catch
      _, _ -> :ok
    end

    # Wait for cleanup
    Process.sleep(100)
  end

  defp print_result(result) do
    IO.puts("""
    Results:
      Duration: #{result.duration}ms
      Success: #{result.successes}/#{result.num_games}
      Failures: #{result.failures}
      Throughput: #{Float.round(result.throughput, 2)} games/sec
      Avg Time: #{Float.round(result.avg_time, 2)}ms
      Min Time: #{result.min_time}ms
      Max Time: #{result.max_time}ms
      P95 Time: #{result.p95_time}ms
    """)
  end

  defp print_summary(results) do
    IO.puts("\n=== Load Test Summary ===\n")

    IO.puts("| Games | Success Rate | Throughput | Avg Time | P95 Time |")
    IO.puts("|-------|--------------|------------|----------|----------|")

    Enum.each(results, fn result ->
      success_rate = Float.round(result.successes / result.num_games * 100, 1)

      IO.puts(
        "| #{String.pad_leading(to_string(result.num_games), 5)} " <>
          "| #{String.pad_leading("#{success_rate}%", 12)} " <>
          "| #{String.pad_leading("#{Float.round(result.throughput, 1)}/s", 10)} " <>
          "| #{String.pad_leading("#{Float.round(result.avg_time, 0)}ms", 8)} " <>
          "| #{String.pad_leading("#{result.p95_time}ms", 8)} |"
      )
    end)

    IO.puts("")

    # Find breaking point
    breaking_point =
      Enum.find(results, fn result ->
        result.successes / result.num_games < 0.95
      end)

    case breaking_point do
      nil ->
        max_tested = Enum.max_by(results, & &1.num_games)

        IO.puts(
          "✅ System handled #{max_tested.num_games} concurrent games with >95% success rate"
        )

      result ->
        IO.puts(
          "⚠️  Breaking point: #{result.num_games} games (#{Float.round(result.successes / result.num_games * 100, 1)}% success rate)"
        )
    end

    IO.puts("")
  end
end

# Run load tests if this file is executed directly
if System.argv() == [] or "--run" in System.argv() do
  Rachel.Benchmarks.LoadTest.run()
end
