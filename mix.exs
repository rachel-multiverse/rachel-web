defmodule Rachel.MixProject do
  use Mix.Project

  def project do
    [
      app: :rachel,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],

      # Docs
      name: "Rachel",
      source_url: "https://github.com/yourusername/rachel-web",
      homepage_url: "https://github.com/yourusername/rachel-web",
      docs: [
        main: "readme",
        extras: [
          "README.md",
          {"../GAME_RULES.md", [title: "Game Rules"]},
          {"../PROTOCOL.md", [title: "Binary Protocol"]},
          "API.md",
          "CONTRIBUTING.md",
          {"DEPLOYMENT.md", [title: "Deployment Guide"]},
          {"docs/DEPENDENCY_UPDATES.md", [title: "Dependency Updates"]},
          {"docs/GENERATING_DOCS.md", [title: "Generating Documentation"]},
          {"benchmarks/README.md", [title: "Performance Benchmarking"]},
          {"config/uptime-monitoring.md", [title: "Uptime Monitoring"]}
        ],
        groups_for_extras: [
          "Game Documentation": [
            "../GAME_RULES.md",
            "../PROTOCOL.md"
          ],
          "Development": [
            "API.md",
            "CONTRIBUTING.md",
            "docs/GENERATING_DOCS.md",
            "docs/DEPENDENCY_UPDATES.md"
          ],
          "Operations": [
            "DEPLOYMENT.md",
            "benchmarks/README.md",
            "config/uptime-monitoring.md"
          ]
        ],
        groups_for_modules: [
          "Game Engine": [
            Rachel.Game.GameState,
            Rachel.Game.GameEngine,
            Rachel.Game.GameSupervisor,
            Rachel.Game.Rules,
            Rachel.Game.Card,
            Rachel.Game.Deck,
            Rachel.Game.Player
          ],
          "Game Management": [
            Rachel.GameManager,
            Rachel.Game.SessionManager,
            Rachel.Game.ConnectionMonitor,
            Rachel.Game.AIPlayer
          ],
          "Web Interface": [
            RachelWeb.GameLive,
            RachelWeb.LobbyLive,
            RachelWeb.ReconnectableLive
          ],
          "Binary Protocol": [
            Rachel.Protocol.Server,
            Rachel.Protocol.Handler,
            Rachel.Protocol.Message
          ]
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {Rachel.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      # Phoenix core
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},

      # Assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Core dependencies
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Binary protocol support
      {:ranch, "~> 2.1"},

      # Testing
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, "~> 0.36", only: :test},
      {:excoveralls, "~> 0.18", only: :test},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},

      # Performance benchmarking
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:benchee_html, "~> 1.0", only: :dev, runtime: false},

      # Documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Rate limiting
      {:hammer, "~> 6.2"},

      # Error tracking
      {:sentry, "~> 10.0"},
      {:hackney, "~> 1.19"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind rachel", "esbuild rachel"],
      "assets.deploy": [
        "tailwind rachel --minify",
        "esbuild rachel --minify",
        "phx.digest"
      ]
    ]
  end
end
