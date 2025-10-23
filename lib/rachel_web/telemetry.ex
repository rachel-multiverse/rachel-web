defmodule RachelWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("rachel.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("rachel.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("rachel.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("rachel.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("rachel.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Game Metrics
      counter("rachel.game.created.count",
        description: "Number of games created"
      ),
      counter("rachel.game.started.count",
        description: "Number of games started"
      ),
      counter("rachel.game.finished.count",
        description: "Number of games finished"
      ),
      counter("rachel.game.error.count",
        tags: [:error_type],
        description: "Number of game errors by type"
      ),
      summary("rachel.game.duration",
        unit: {:native, :second},
        description: "Game duration from start to finish"
      ),
      distribution("rachel.game.players",
        buckets: [2, 3, 4, 5, 6, 7, 8],
        description: "Distribution of player counts"
      ),
      last_value("rachel.game.active.count",
        description: "Current number of active games"
      ),

      # User Metrics
      counter("rachel.user.registered.count",
        description: "Number of users registered"
      ),
      counter("rachel.user.login.count",
        description: "Number of user logins"
      ),
      last_value("rachel.user.online.count",
        description: "Current number of online users"
      )
    ]
  end

  defp periodic_measurements do
    [
      # Measure active games every 10 seconds
      {__MODULE__, :measure_active_games, []},
      # Measure online users every 10 seconds
      {__MODULE__, :measure_online_users, []}
    ]
  end

  def measure_active_games do
    # Safely count games, handling case where supervisor isn't running (e.g., in tests)
    count =
      try do
        Rachel.Game.GameSupervisor.list_games() |> length()
      catch
        :exit, _ -> 0
      end

    :telemetry.execute([:rachel, :game, :active], %{count: count}, %{})
  end

  def measure_online_users do
    # Count active LiveView processes as a proxy for online users
    # This counts connected LiveView sockets across all games
    count =
      try do
        Supervisor.count_children(RachelWeb.Endpoint)
        |> Map.get(:active, 0)
      catch
        :exit, _ -> 0
      end

    :telemetry.execute([:rachel, :user, :online], %{count: count}, %{})
  end
end
