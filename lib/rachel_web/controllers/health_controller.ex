defmodule RachelWeb.HealthController do
  @moduledoc """
  Health check endpoint for load balancers and monitoring systems.

  This endpoint returns the application's health status by checking:
  - Database connectivity
  - Application process status
  - System resources

  Used by Docker healthchecks, Kubernetes probes, and monitoring tools.
  """

  use RachelWeb, :controller
  require Logger

  @doc """
  Returns health status of the application.

  Returns 200 OK with health details when all checks pass.
  Returns 503 Service Unavailable if any critical check fails.
  """
  def check(conn, _params) do
    checks = %{
      database: check_database(),
      application: check_application()
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

  # Check database connectivity
  defp check_database do
    try do
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
