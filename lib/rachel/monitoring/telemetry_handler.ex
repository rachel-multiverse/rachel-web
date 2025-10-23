defmodule Rachel.Monitoring.TelemetryHandler do
  @moduledoc """
  Telemetry event handler for monitoring and alerting.

  This module attaches to telemetry events and checks metrics against
  configured alert thresholds. When thresholds are exceeded, it triggers
  alerts through the configured notification channels.

  ## Usage

  This handler is automatically attached during application startup.
  No manual configuration is required.

  ## Monitored Events

  - `[:phoenix, :router_dispatch, :stop]` - HTTP response times
  - `[:rachel, :game, :error]` - Game error rates
  - `[:rachel, :repo, :query]` - Database query performance
  - `[:vm, :memory]` - Memory usage
  """

  require Logger
  alias Rachel.Monitoring.Alerts

  @doc """
  Attaches telemetry handlers for monitoring critical metrics.

  This should be called during application startup.
  """
  def attach do
    events = [
      [:phoenix, :router_dispatch, :stop],
      [:rachel, :game, :error],
      [:rachel, :repo, :query, :stop],
      [:vm, :memory]
    ]

    :telemetry.attach_many(
      "rachel-monitoring-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Detaches all telemetry handlers.

  Useful for testing or graceful shutdown.
  """
  def detach do
    :telemetry.detach("rachel-monitoring-handler")
  end

  @doc """
  Handles telemetry events and checks against alert thresholds.
  """
  def handle_event([:phoenix, :router_dispatch, :stop], measurements, metadata, _config) do
    # Check response time
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    case Alerts.check_threshold(:response_time_ms, duration_ms) do
      {:alert, alert} ->
        Alerts.handle_alert({:alert, alert},
          notify: get_notification_channels(:warning),
          metadata: %{
            route: metadata[:route],
            status: metadata[:status]
          }
        )

      {:ok, :healthy} ->
        :ok
    end
  end

  def handle_event([:rachel, :game, :error], measurements, metadata, _config) do
    # Track game errors - if error rate gets too high, alert
    # This is a simple per-event check; in production you'd want
    # to calculate error rate over a time window
    error_count = measurements[:count] || 1

    Logger.warning("Game error detected",
      error_type: metadata[:error_type],
      game_id: metadata[:game_id],
      count: error_count
    )

    # In production, you would:
    # 1. Store errors in a time-windowed buffer (e.g., ETS table)
    # 2. Calculate error_rate = errors / total_games over last N minutes
    # 3. Alert if error_rate exceeds thresholds

    # For now, just log critical error types immediately
    if metadata[:error_type] == :too_many_errors do
      alert = %{
        severity: :critical,
        metric: :game_corruption,
        value: error_count,
        threshold: 1,
        message: "Game #{metadata[:game_id]} corrupted due to excessive errors"
      }

      Alerts.handle_alert({:alert, alert},
        notify: get_notification_channels(:critical),
        metadata: metadata
      )
    end
  end

  def handle_event([:rachel, :repo, :query, :stop], measurements, metadata, _config) do
    # Check database query time
    query_time_ms =
      System.convert_time_unit(measurements.query_time || 0, :native, :millisecond)

    case Alerts.check_threshold(:db_query_time_ms, query_time_ms) do
      {:alert, alert} ->
        Alerts.handle_alert({:alert, alert},
          notify: get_notification_channels(:warning),
          metadata: %{
            query: String.slice(metadata[:query] || "", 0, 100),
            source: metadata[:source]
          }
        )

      {:ok, :healthy} ->
        :ok
    end
  end

  def handle_event([:vm, :memory], measurements, _metadata, _config) do
    # Check memory usage
    total_memory_mb = div(measurements[:total] || 0, 1_024 * 1_024)

    case Alerts.check_threshold(:memory_mb, total_memory_mb) do
      {:alert, alert} ->
        Alerts.handle_alert({:alert, alert},
          notify: get_notification_channels(:warning),
          metadata: %{
            processes: measurements[:processes],
            system: measurements[:system]
          }
        )

      {:ok, :healthy} ->
        :ok
    end
  end

  # Determines which notification channels to use based on environment and severity
  defp get_notification_channels(severity) do
    env = Application.get_env(:rachel, :env, :dev)

    case {env, severity} do
      # Production: Use all configured channels
      {:prod, :critical} -> [:log, :sentry, :webhook]
      {:prod, :warning} -> [:log, :webhook]
      {:prod, _} -> [:log]
      # Non-production: Only log
      _ -> [:log]
    end
  end
end
