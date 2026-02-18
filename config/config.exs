# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# 1. General application configuration
# We use :utc_datetime_usec for microsecond precision in financial records.
config :nexus,
  ecto_repos: [Nexus.Repo],
  generators: [timestamp_type: :utc_datetime_usec, binary_id: true]

# 2. Register the Event Store
# We set this to empty to prevent the library from auto-starting it,
# as it will be managed as a child of Nexus.App.
config :nexus, event_stores: []

# 3. Configure Event Store database settings
# column_data_type: "jsonb" allows for efficient metadata queries.
# schema: "event_store" matches our manual CREATE SCHEMA command.
config :nexus, Nexus.EventStore,
  column_data_type: "jsonb",
  serializer: Commanded.Serialization.JsonSerializer,
  schema: "event_store",
  types: EventStore.PostgresTypes

# 4. Configure the Commanded App (The Dispatcher)
config :nexus, Nexus.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Nexus.EventStore
  ],
  pubsub: :local,
  registry: :local,
  router: Nexus.Router

# Configures the endpoint
config :nexus, NexusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: NexusWeb.ErrorHTML, json: NexusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Nexus.PubSub,
  live_view: [signing_salt: "BEwJNThU"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :nexus, Nexus.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  nexus: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  nexus: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# 5. Rate Limiting (Hammer)
# Configure Hammer with an ETS backend for high-performance rate limiting.
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000, cleanup_interval_ms: 60_000]}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
