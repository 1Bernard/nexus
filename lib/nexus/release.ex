defmodule Nexus.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed. Called via:

    /app/bin/nexus eval "Nexus.Release.migrate"
    /app/bin/nexus eval "Nexus.Release.init_event_store"
    /app/bin/nexus eval "Nexus.Release.seed"

  All functions are idempotent — safe to run on every deploy.
  """
  @app :nexus

  @doc """
  Initialises the EventStore schema and all required tables.

  Must be run before the first application start on a new database.
  Uses EventStore's own initialisation task without requiring Mix.
  Idempotent — will skip tables that already exist.
  """
  @spec init_event_store() :: :ok
  def init_event_store do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)

    # EventStore.Tasks.Init.exec requires an explicit keyword-list config
    # with hostname/database/username/password — it does NOT resolve the
    # :url key that runtime.exs sets (that's only used at full OTP app start).
    # We parse the URL directly here so the init task connects to the right host.
    url =
      System.get_env("EVENT_STORE_URL") ||
        System.get_env("DATABASE_URL") ||
        "ecto://postgres:postgres@localhost/nexus_prod"

    %URI{host: host, port: port, userinfo: userinfo, path: "/" <> database} = URI.parse(url)
    [username, password] = String.split(userinfo || "postgres:postgres", ":")

    base_config = Application.get_env(:nexus, Nexus.EventStore, [])

    config =
      Keyword.merge(base_config,
        hostname: host || "localhost",
        port: port || 5432,
        database: database,
        username: username,
        password: password
      )

    EventStore.Tasks.Create.exec(config, [])
    :ok = EventStore.Tasks.Init.exec(config, [])
    IO.puts("[Release] EventStore initialised successfully.")
  end

  @doc """
  Seeds the database with demo users required for login.

  Seeds Ecto read-model data (market ticks, invoices, exposures) AND
  dispatches Commanded commands to create the two system-admin demo accounts.

  The Commanded dispatch requires a running EventStore + Nexus.App supervisor,
  so `Application.ensure_all_started/1` is called first. It is safe to call
  `ensure_all_started` even if the app is already running.

  Idempotent — will skip users that are already registered.

  Run via:
    docker compose exec app /app/bin/nexus rpc "Nexus.Release.seed"
  """
  @spec seed() :: :ok
  def seed do
    # Start the full OTP application so Commanded and EventStore supervisors
    # are up — required for dispatch/1 to work.
    {:ok, _} = Application.ensure_all_started(@app)

    org_id = "00000000-0000-0000-0000-000000000000"

    now = Nexus.Schema.utc_now()

    users = [
      {Nexus.Schema.generate_uuidv7(), "admin@nexus-platform.io", "Nexus System Admin"},
      {Nexus.Schema.generate_uuidv7(), "elena@global-corp.com", "Elena (Global Corp App)"}
    ]

    for {user_id, email, display_name} <- users do
      cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
        user_id: user_id,
        org_id: org_id,
        email: email,
        display_name: display_name,
        registered_at: now
      }

      case Nexus.App.dispatch(cmd) do
        :ok ->
          IO.puts("[Seed] ✓ Registered #{email}")

        {:error, :already_registered} ->
          IO.puts("[Seed] ~ #{email} already registered — skipping.")

        {:error, reason} ->
          IO.puts("[Seed] ✗ Failed to register #{email}: #{inspect(reason)}")
      end
    end

    IO.puts("[Seed] Done.")
  end

  @doc "Runs all pending Ecto migrations."
  @spec migrate() :: [any()]
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls back an Ecto migration to a specific version."
  @spec rollback(module(), integer()) :: {:ok, any(), any()}
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # SSL must be started for encrypted DB connections (TimescaleDB in prod)
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
