import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :nexus, Nexus.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: System.get_env("DB_NAME") || "nexus_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :nexus, Nexus.EventStore,
  column_data_type: "jsonb",
  serializer: Commanded.Serialization.JsonSerializer,
  types: EventStore.PostgresTypes,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: System.get_env("DB_NAME") || "nexus_test",
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :nexus, NexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PDMGePlFvikFJfcV9iNL5Bn6PyUnM5XgWLsbcd+4wZQ6Tfauk6uMZnJ/QVdt4kCA",
  server: false

# In test we don't send emails
config :nexus, Nexus.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
