defmodule Rachel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Build children list, conditionally including GameCleanup
    base_children = [
      RachelWeb.Telemetry,
      Rachel.Repo,
      {DNSCluster, query: Application.get_env(:rachel, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Rachel.PubSub},
      # Game-related processes
      {Registry, keys: :unique, name: Rachel.GameRegistry},
      Rachel.Game.SessionManager,
      Rachel.Game.ConnectionMonitor,
      Rachel.Game.GameSupervisor
    ]

    # Add GameCleanup only if enabled (disabled in tests)
    children =
      if Application.get_env(:rachel, :game_cleanup_enabled, true) do
        base_children ++ [Rachel.Game.GameCleanup, RachelWeb.Endpoint]
      else
        base_children ++ [RachelWeb.Endpoint]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rachel.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Attach telemetry handlers for monitoring and alerting
        Rachel.Monitoring.TelemetryHandler.attach()

        # Attach analytics telemetry handler for game statistics
        Rachel.Analytics.TelemetryHandler.attach()

        # Restore active games from database after supervisor starts
        # Skip in test environment to avoid Ecto.Sandbox issues
        unless Application.get_env(:rachel, :env) == :test do
          Task.start(fn -> restore_games() end)
        end

        {:ok, pid}

      error ->
        error
    end
  end

  defp restore_games do
    require Logger

    game_ids = Rachel.GameManager.restore_active_games()

    if length(game_ids) > 0 do
      Logger.info("Restored #{length(game_ids)} games from database")
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RachelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
