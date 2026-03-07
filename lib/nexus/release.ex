defmodule Nexus.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed. Called via:

    /app/bin/nexus eval "Nexus.Release.migrate"
    /app/bin/nexus eval "Nexus.Release.init_event_store"

  Both functions are idempotent — safe to run on every deploy.
  """
  @app :nexus

  @doc """
  Initialises the EventStore schema and all required tables.

  Must be run before the first application start on a new database.
  Uses EventStore's own initialisation task without requiring Mix.
  Idempotent — will skip tables that already exist.
  """
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

    :ok = EventStore.Tasks.Init.exec(config, [])
    IO.puts("[Release] EventStore initialised successfully.")
  end

  @doc "Runs all pending Ecto migrations."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls back an Ecto migration to a specific version."
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
