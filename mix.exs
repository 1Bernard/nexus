defmodule Nexus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexus,
      version: "0.1.0",
      # Updated to match your local environment
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {Nexus.Application, []},
      # :crypto is required for WebAuthn and ERP signature verification
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # --- Phoenix Core ---
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # --- CQRS / Event Sourcing ---
      {:commanded, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:commanded_ecto_projections, "~> 1.4"},
      {:eventstore, "~> 1.4"},

      # --- Identity & Security (SecureFlow ID) ---
      # Per documentation: :wax_ is the correct name due to name collision.
      {:wax_, "~> 0.7.0"},
      # Time-ordered UUIDs for the ledger
      {:uuidv7, "~> 1.0"},
      # General ID utilities
      {:uniq, "~> 0.6"},
      # Rate limiting for SAP/Oracle APIs
      {:hammer, "~> 6.1"},

      # --- Real-time & Data (Kantox Nexus) ---
      # High-performance HTTP client for ERP
      {:finch, "~> 0.19"},
      # WebSocket client for market ticks
      {:websockex, "~> 0.4"},
      # Time-series hypertable support
      {:timescale, "~> 0.1"},
      # Financial precision for currency math
      {:decimal, "~> 2.3"},

      # --- Testing & BDD ---
      # Gherkin BDD implementation
      {:cabbage, "~> 0.4.0"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.features": ["test --only feature"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind nexus", "esbuild nexus"],
      "assets.deploy": ["tailwind nexus --minify", "esbuild nexus --minify", "phx.digest"]
    ]
  end
end
