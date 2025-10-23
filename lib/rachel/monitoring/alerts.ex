defmodule Rachel.Monitoring.Alerts do
  @moduledoc """
  Alert threshold configuration and monitoring rules for production health.

  This module defines critical thresholds for various metrics and provides
  functions to check if current values exceed alert conditions.

  ## Alert Severity Levels

  - **critical**: Immediate attention required, service degradation likely
  - **warning**: Attention needed soon, approaching critical thresholds
  - **info**: Notable event, no immediate action required

  ## Alerting Strategy

  Alerts are configured with both thresholds and time windows to reduce noise:
  - Critical alerts: Immediate notification
  - Warning alerts: Aggregated over 5-minute windows
  - Info alerts: Daily digest

  ## Integration

  This module is designed to work with:
  - Sentry for error tracking and alerting
  - Phoenix LiveDashboard for visualization
  - Custom telemetry handlers for real-time monitoring
  """

  require Logger

  @type severity :: :critical | :warning | :info
  @type alert :: %{
          name: atom(),
          severity: severity(),
          threshold: number(),
          current: number(),
          message: String.t()
        }

  # Performance Thresholds
  @response_time_critical_ms 2000
  @response_time_warning_ms 1000
  @error_rate_critical 0.05
  @error_rate_warning 0.02

  # Resource Thresholds
  @memory_critical_mb 1024
  @memory_warning_mb 768
  @cpu_critical_percent 90
  @cpu_warning_percent 70

  # Game Health Thresholds
  @game_error_rate_critical 0.10
  @game_error_rate_warning 0.05
  @active_games_max 1000
  @game_duration_max_minutes 120

  # Database Thresholds
  @db_query_time_critical_ms 1000
  @db_query_time_warning_ms 500
  @db_connection_pool_critical 0.90
  @db_connection_pool_warning 0.70

  @doc """
  Returns the configured alert thresholds as a map.

  ## Example

      iex> Rachel.Monitoring.Alerts.thresholds()
      %{
        response_time: %{critical: 2000, warning: 1000},
        error_rate: %{critical: 0.05, warning: 0.02},
        ...
      }
  """
  def thresholds do
    %{
      # HTTP Performance
      response_time_ms: %{
        critical: @response_time_critical_ms,
        warning: @response_time_warning_ms,
        description: "HTTP response time in milliseconds"
      },
      error_rate: %{
        critical: @error_rate_critical,
        warning: @error_rate_warning,
        description: "Ratio of errors to total requests (0.0-1.0)"
      },

      # System Resources
      memory_mb: %{
        critical: @memory_critical_mb,
        warning: @memory_warning_mb,
        description: "Memory usage in megabytes"
      },
      cpu_percent: %{
        critical: @cpu_critical_percent,
        warning: @cpu_warning_percent,
        description: "CPU utilization percentage"
      },

      # Game Health
      game_error_rate: %{
        critical: @game_error_rate_critical,
        warning: @game_error_rate_warning,
        description: "Ratio of game errors to total games (0.0-1.0)"
      },
      active_games: %{
        critical: @active_games_max,
        warning: trunc(@active_games_max * 0.8),
        description: "Number of concurrent active games"
      },
      game_duration_minutes: %{
        critical: @game_duration_max_minutes,
        warning: trunc(@game_duration_max_minutes * 0.8),
        description: "Individual game duration in minutes"
      },

      # Database Performance
      db_query_time_ms: %{
        critical: @db_query_time_critical_ms,
        warning: @db_query_time_warning_ms,
        description: "Database query execution time in milliseconds"
      },
      db_connection_pool_usage: %{
        critical: @db_connection_pool_critical,
        warning: @db_connection_pool_warning,
        description: "Database connection pool utilization (0.0-1.0)"
      }
    }
  end

  @doc """
  Checks if a metric value exceeds alert thresholds.

  Returns `{:ok, :healthy}` if the value is within acceptable ranges,
  or `{:alert, %{severity: _, message: _}}` if a threshold is exceeded.

  ## Examples

      iex> Rachel.Monitoring.Alerts.check_threshold(:response_time_ms, 500)
      {:ok, :healthy}

      iex> Rachel.Monitoring.Alerts.check_threshold(:response_time_ms, 1500)
      {:alert, %{severity: :warning, message: "Response time (1500ms) exceeds warning threshold (1000ms)"}}

      iex> Rachel.Monitoring.Alerts.check_threshold(:response_time_ms, 2500)
      {:alert, %{severity: :critical, message: "Response time (2500ms) exceeds critical threshold (2000ms)"}}
  """
  def check_threshold(metric_name, value) when is_number(value) do
    case Map.get(thresholds(), metric_name) do
      nil ->
        {:error, :unknown_metric}

      thresholds ->
        cond do
          value >= thresholds.critical ->
            {:alert,
             %{
               severity: :critical,
               metric: metric_name,
               value: value,
               threshold: thresholds.critical,
               message:
                 "#{format_metric_name(metric_name)} (#{value}) exceeds critical threshold (#{thresholds.critical})"
             }}

          value >= thresholds.warning ->
            {:alert,
             %{
               severity: :warning,
               metric: metric_name,
               value: value,
               threshold: thresholds.warning,
               message:
                 "#{format_metric_name(metric_name)} (#{value}) exceeds warning threshold (#{thresholds.warning})"
             }}

          true ->
            {:ok, :healthy}
        end
    end
  end

  @doc """
  Formats a metric name for human-readable alert messages.
  """
  def format_metric_name(metric_name) do
    metric_name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Handles alert events by logging and potentially triggering external alerts.

  In production, this would integrate with:
  - Sentry for error tracking
  - PagerDuty/OpsGenie for on-call alerts
  - Slack/Discord for team notifications

  ## Options

  - `:notify` - List of notification channels (default: [:log])
  - `:metadata` - Additional context for the alert

  ## Examples

      Rachel.Monitoring.Alerts.handle_alert(
        {:alert, %{severity: :critical, message: "High error rate"}},
        notify: [:log, :sentry],
        metadata: %{environment: :production}
      )
  """
  def handle_alert(result, opts \\ [])

  def handle_alert({:ok, :healthy}, _opts), do: :ok

  def handle_alert({:alert, alert}, opts) do
    notify_channels = Keyword.get(opts, :notify, [:log])
    metadata = Keyword.get(opts, :metadata, %{})

    # Always log alerts
    log_alert(alert, metadata)

    # Notify configured channels
    Enum.each(notify_channels, fn channel ->
      notify_channel(channel, alert, metadata)
    end)

    {:ok, :alerted}
  end

  defp log_alert(%{severity: :critical} = alert, alert_metadata) do
    Logger.error("[ALERT:CRITICAL] #{alert.message}",
      metric: alert.metric,
      value: alert.value,
      threshold: alert.threshold,
      alert_data: alert_metadata
    )
  end

  defp log_alert(%{severity: :warning} = alert, alert_metadata) do
    Logger.warning("[ALERT:WARNING] #{alert.message}",
      metric: alert.metric,
      value: alert.value,
      threshold: alert.threshold,
      alert_data: alert_metadata
    )
  end

  defp log_alert(%{severity: :info} = alert, alert_metadata) do
    Logger.info("[ALERT:INFO] #{alert.message}",
      metric: alert.metric,
      value: alert.value,
      alert_data: alert_metadata
    )
  end

  defp notify_channel(:log, _alert, _metadata), do: :ok

  defp notify_channel(:sentry, alert, metadata) do
    # Sentry integration for error tracking
    # Only send critical alerts to Sentry to avoid noise
    if alert.severity == :critical do
      message = "[#{alert.severity}] #{alert.message}"

      Sentry.capture_message(message,
        level: :error,
        extra: Map.merge(metadata, %{metric: alert.metric, threshold: alert.threshold})
      )
    end

    :ok
  end

  defp notify_channel(:webhook, alert, metadata) do
    # Generic webhook integration for custom alerting systems
    # This could be Slack, Discord, PagerDuty, etc.
    webhook_url = Application.get_env(:rachel, :alert_webhook_url)

    if webhook_url do
      payload = %{
        severity: alert.severity,
        message: alert.message,
        metric: alert.metric,
        value: alert.value,
        threshold: alert.threshold,
        metadata: metadata,
        timestamp: DateTime.utc_now()
      }

      # Use Task.Supervisor for non-blocking webhook calls
      Task.start(fn ->
        case Req.post(webhook_url, json: payload) do
          {:ok, _response} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to send alert webhook: #{inspect(reason)}")
        end
      end)
    end

    :ok
  end

  defp notify_channel(_unknown, _alert, _metadata), do: :ok
end
