defmodule RachelWeb.HealthController do
  @moduledoc """
  Health check endpoints for uptime monitoring and service health status.

  Provides three types of health checks:
  - `/health` - Basic health check (fast, minimal dependencies)
  - `/health/ready` - Readiness check (verifies all dependencies)
  - `/health/live` - Liveness check (verifies application is responsive)

  Used by Docker healthchecks, Kubernetes probes, load balancers, and
  external monitoring services (UptimeRobot, Pingdom, etc.)
  """

  use RachelWeb, :controller
  require Logger

  @doc """
  Basic health check - fast response with minimal checks.

  Only verifies the application can respond to requests.
  Use for high-frequency monitoring and load balancer checks.

  Returns 200 OK with minimal response.
  """
  def index(conn, _params) do
    checks = %{
      database: check_database(),
      application: check_application()
    }

    all_healthy = Enum.all?(checks, fn {_name, status} -> status == :ok end)

    json(conn, %{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:rachel, :vsn) |> to_string(),
      checks: format_checks(checks)
    })
  end

  @doc """
  Legacy health check endpoint - comprehensive dependency verification.

  Kept for backward compatibility. For new deployments, use:
  - `/health` for basic checks
  - `/health/ready` for readiness checks
  - `/health/live` for liveness checks

  Returns 200 OK with health details when all checks pass.
  Returns 503 Service Unavailable if any critical check fails.
  """
  def check(conn, _params) do
    checks = %{
      database: check_database(),
      application: check_application(),
      game_supervisor: check_game_supervisor(),
      pubsub: check_pubsub()
    }

    all_healthy = Enum.all?(checks, fn {_name, status} -> status == :ok end)

    status = if all_healthy, do: :ok, else: :service_unavailable

    conn
    |> put_status(status)
    |> json(%{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:rachel, :vsn) |> to_string(),
      checks: format_checks(checks)
    })
  end

  @doc """
  Readiness check - verifies all dependencies are available.

  Checks:
  - Database connectivity
  - Essential services (GameSupervisor, PubSub)

  Use for:
  - Kubernetes readiness probes
  - Before routing traffic to a new instance
  - Deployment verification

  Returns:
  - 200 if all checks pass
  - 503 if any check fails (service not ready)
  """
  def ready(conn, _params) do
    checks = %{
      database: check_database(),
      game_supervisor: check_game_supervisor(),
      pubsub: check_pubsub()
    }

    all_healthy = Enum.all?(checks, fn {_name, status} -> status == :ok end)

    conn
    |> put_status(if all_healthy, do: :ok, else: :service_unavailable)
    |> json(%{
      status: if(all_healthy, do: "ready", else: "not_ready"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: format_checks(checks)
    })
  end

  @doc """
  Liveness check - verifies the application is alive and responsive.

  Checks:
  - BEAM scheduler responsiveness
  - Memory usage within limits

  Use for:
  - Kubernetes liveness probes
  - Detecting application hangs
  - Triggering restarts for unrecoverable states

  Returns:
  - 200 if application is responsive
  - 503 if application appears stuck
  """
  def live(conn, _params) do
    checks = %{
      scheduler: check_scheduler(),
      memory: check_memory()
    }

    all_healthy = Enum.all?(checks, fn {_name, status} -> status == :ok end)

    conn
    |> put_status(if all_healthy, do: :ok, else: :service_unavailable)
    |> json(%{
      status: if(all_healthy, do: "alive", else: "stuck"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: format_checks(checks)
    })
  end

  # Check database connectivity
  defp check_database do
    case Ecto.Adapters.SQL.query(Rachel.Repo, "SELECT 1", []) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Database health check failed: #{inspect(error)}")
        :error
    end
  rescue
    error ->
      Logger.error("Database health check exception: #{inspect(error)}")
      :error
  end

  # Check application process status
  defp check_application do
    # Verify the Rachel application is running
    case Application.get_env(:rachel, RachelWeb.Endpoint) do
      nil ->
        Logger.error("Application configuration not found")
        :error

      _config ->
        :ok
    end
  end

  # Check GameSupervisor is running
  defp check_game_supervisor do
    case GenServer.whereis(Rachel.Game.GameSupervisor) do
      nil ->
        Logger.error("GameSupervisor not found")
        :error

      pid when is_pid(pid) ->
        :ok
    end
  catch
    _, error ->
      Logger.error("GameSupervisor check failed: #{inspect(error)}")
      :error
  end

  # Check PubSub is running
  defp check_pubsub do
    case Process.whereis(Rachel.PubSub) do
      nil ->
        Logger.error("PubSub not found")
        :error

      pid when is_pid(pid) ->
        :ok
    end
  catch
    _, error ->
      Logger.error("PubSub check failed: #{inspect(error)}")
      :error
  end

  # Check BEAM scheduler responsiveness
  defp check_scheduler do
    # Enable scheduler wall time tracking if not already enabled
    :erlang.system_flag(:scheduler_wall_time, true)
    utilization = :erlang.statistics(:scheduler_wall_time_all)

    if is_list(utilization) and length(utilization) > 0 do
      :ok
    else
      Logger.error("Scheduler check failed: no utilization data")
      :error
    end
  catch
    _, error ->
      Logger.error("Scheduler check failed: #{inspect(error)}")
      :error
  end

  # Check memory usage is within limits
  defp check_memory do
    memory = :erlang.memory(:total)
    # 2GB limit for liveness check
    max_memory = 2 * 1024 * 1024 * 1024

    if memory < max_memory do
      :ok
    else
      Logger.error("Memory usage (#{div(memory, 1024 * 1024)}MB) exceeds limit")
      :error
    end
  catch
    _, error ->
      Logger.error("Memory check failed: #{inspect(error)}")
      :error
  end

  # Format check results for JSON response
  defp format_checks(checks) do
    checks
    |> Enum.map(fn {name, status} ->
      {name,
       %{
         status: if(status == :ok, do: "pass", else: "fail")
       }}
    end)
    |> Enum.into(%{})
  end
end
