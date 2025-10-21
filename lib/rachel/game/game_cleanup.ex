defmodule Rachel.Game.GameCleanup do
  @moduledoc """
  Periodically cleans up stale game processes to prevent memory leaks.

  Cleanup rules:
  - Finished games older than 1 hour
  - Waiting (lobby) games inactive for 30 minutes
  - Playing games inactive for 2 hours (abandoned)
  """

  use GenServer
  require Logger

  alias Rachel.GameManager

  # Check every 5 minutes
  @check_interval :timer.minutes(5)

  # Inactivity thresholds
  @finished_game_ttl :timer.hours(1)
  @waiting_game_ttl :timer.minutes(30)
  @playing_game_ttl :timer.hours(2)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger a cleanup (useful for testing).
  Returns the number of games cleaned up.
  """
  def cleanup_now do
    GenServer.call(__MODULE__, :cleanup_now)
  end

  @doc """
  Get cleanup statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      total_cleaned: 0,
      last_cleanup_at: nil,
      cleanup_history: []
    }

    # Schedule first cleanup
    schedule_cleanup()

    Logger.info("Game cleanup worker started")
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleaned_count = perform_cleanup()

    new_state = %{
      state
      | total_cleaned: state.total_cleaned + cleaned_count,
        last_cleanup_at: DateTime.utc_now(),
        cleanup_history: add_to_history(state.cleanup_history, cleaned_count)
    }

    if cleaned_count > 0 do
      Logger.info("Game cleanup completed: #{cleaned_count} games removed")
    end

    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:cleanup_now, _from, state) do
    cleaned_count = perform_cleanup()

    new_state = %{
      state
      | total_cleaned: state.total_cleaned + cleaned_count,
        last_cleanup_at: DateTime.utc_now(),
        cleanup_history: add_to_history(state.cleanup_history, cleaned_count)
    }

    {:reply, cleaned_count, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_cleaned: state.total_cleaned,
      last_cleanup_at: state.last_cleanup_at,
      recent_cleanups: Enum.take(state.cleanup_history, 10)
    }

    {:reply, stats, state}
  end

  ## Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @check_interval)
  end

  defp perform_cleanup do
    now = DateTime.utc_now()

    GameManager.list_games()
    |> Enum.map(&{&1, get_game_info(&1)})
    |> Enum.filter(fn {_game_id, info} -> info != nil end)
    |> Enum.filter(fn {_game_id, info} -> should_cleanup?(info, now) end)
    |> Enum.map(fn {game_id, info} -> cleanup_game(game_id, info) end)
    |> Enum.count(&(&1 == :ok))
  end

  defp get_game_info(game_id) do
    case GameManager.get_game(game_id) do
      {:ok, game} -> game
      {:error, _} -> nil
    end
  end

  defp should_cleanup?(game, now) do
    case game.status do
      :finished ->
        # Clean up finished games after 1 hour
        seconds_inactive = DateTime.diff(now, game.last_action_at)
        seconds_inactive >= div(@finished_game_ttl, 1000)

      :waiting ->
        # Clean up waiting lobbies after 30 minutes of inactivity
        seconds_inactive = DateTime.diff(now, game.last_action_at)
        seconds_inactive >= div(@waiting_game_ttl, 1000)

      :playing ->
        # Clean up abandoned games after 2 hours of inactivity
        seconds_inactive = DateTime.diff(now, game.last_action_at)
        seconds_inactive >= div(@playing_game_ttl, 1000)

      _ ->
        false
    end
  end

  defp cleanup_game(game_id, game) do
    Logger.debug(
      "Cleaning up #{game.status} game #{game_id}: inactive for #{inactive_duration(game)} minutes"
    )

    # End the GenServer process
    case GameManager.end_game(game_id) do
      :ok ->
        # Also delete from database
        GameManager.delete_game_record(game_id)
        :ok

      {:error, :not_found} ->
        # Already cleaned up from memory, just delete DB record
        GameManager.delete_game_record(game_id)
        :ok

      error ->
        Logger.warning("Failed to cleanup game #{game_id}: #{inspect(error)}")
        :error
    end
  end

  defp inactive_duration(game) do
    now = DateTime.utc_now()
    seconds = DateTime.diff(now, game.last_action_at)
    div(seconds, 60)
  end

  defp add_to_history(history, count) do
    entry = %{
      timestamp: DateTime.utc_now(),
      games_cleaned: count
    }

    # Keep last 100 entries
    [entry | history] |> Enum.take(100)
  end
end
