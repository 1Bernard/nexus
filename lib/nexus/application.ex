defmodule Nexus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  # Capture the Mix environment at compile time so it's available in releases
  # where Mix itself is not loaded. Mix.env() is unavailable in prod releases.
  @env Mix.env()

  @impl true
  def start(_type, _args) do
    Logger.info("[Nexus] Application starting in #{@env} environment")

    # Initialize EventStore schema BEFORE starting Commanded.
    # EventStore.Tasks.Init.exec does NOT auto-parse the :url config key;
    # it needs explicit hostname/database/username/password keyword params.
    # We parse DATABASE_URL directly here to build those params.
    # At Application.start/2 time, all OTP deps (including db_connection) are
    # running, so this works. Idempotent: a no-op if schema already exists.
    #
    # IMPORTANT: EventStore.Tasks.Init.exec assumes the PostgreSQL schema named
    # in `schema:` already exists (it sets search_path to it). We must run
    # EventStore.Tasks.Create.exec FIRST — which creates `CREATE SCHEMA IF NOT
    # EXISTS event_store` within the existing database. Both calls are idempotent.
    if @env != :test do
      url =
        System.get_env("EVENT_STORE_URL") ||
          System.get_env("DATABASE_URL") ||
          "ecto://postgres:postgres@localhost/nexus_prod"

      %URI{host: host, port: port, userinfo: userinfo, path: "/" <> database} = URI.parse(url)
      [username, password] = String.split(userinfo || "postgres:postgres", ":")

      event_store_config =
        Application.get_env(:nexus, Nexus.EventStore, [])
        |> Keyword.merge(
          hostname: host || "localhost",
          port: port || 5432,
          database: database,
          username: username,
          password: password
        )

      # Step 1: Create the PostgreSQL schema (e.g. `event_store`) if not exists.
      EventStore.Tasks.Create.exec(event_store_config, [])
      # Step 2: Create tables within that schema.
      :ok = EventStore.Tasks.Init.exec(event_store_config, [])
      Logger.info("[Nexus] EventStore schema ready.")
    end

    children = [
      # 1. Infrastructure (Database & Event Store)
      NexusWeb.Telemetry,
      Nexus.Repo,
      {DNSCluster, query: Application.get_env(:nexus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Nexus.PubSub},
      NexusWeb.Presence,
      {Finch, name: Nexus.Finch},

      # 2. Domain Supervisors (The "Monolith" Segregation)
      Nexus.Identity.AuthChallengeStore,
      Nexus.Treasury.Gateways.PriceCache,
      {Nx.Serving,
       serving: Nexus.Intelligence.Services.SentimentAnalyzer.serving(),
       name: Nexus.Intelligence.SentimentServing,
       batch_size: 1,
       batch_timeout: 100},
      # 3. Commanded Application (Command Dispatcher)
      Nexus.App,
      # --- Intelligence Domain ---
      # --- Reporting Domain ---

      # 4. Web Transport
      NexusWeb.Endpoint
    ]

    children =
      if @env == :test do
        children
      else
        children ++
          [
            Nexus.Intelligence.Projectors.AnalysisProjector,
            Nexus.Reporting.Projectors.AuditProjector,
            # WebSocket gateway — requires live network; excluded in test env
            Nexus.Treasury.Gateways.PolygonClient,
            Nexus.Treasury.Gateways.MarketSimulator,
            Nexus.Identity.Projectors.UserRegistrationProjector,
            Nexus.Identity.Projectors.UserProjector,
            # --- Organization Domain ---
            Nexus.Organization.Projectors.TenantProjector,
            Nexus.Organization.Projectors.InvitationProjector,
            # --- ERP Domain ---
            Nexus.ERP.Projectors.InvoiceProjector,
            Nexus.ERP.Projectors.StatementProjector,
            # --- Treasury Domain ---
            Nexus.Treasury.Projectors.MarketTickProjector,
            Nexus.Treasury.Projectors.ExposureProjector,
            Nexus.Treasury.Projectors.PolicyProjector,
            Nexus.Treasury.Projectors.ForecastProjector,
            Nexus.Treasury.Projectors.ReconciliationProjector,
            Nexus.Payments.Projectors.BulkPaymentProjector,
            # --- Bridge Handlers ---
            Nexus.Treasury.Handlers.ExposureBridge,
            Nexus.Treasury.Handlers.ExposurePolicyHandler,
            Nexus.Intelligence.Handlers.InvoiceAnalyzer,
            # --- Real-Time Notification Handlers (Rule 3) ---
            Nexus.Payments.Handlers.BulkPaymentHandler,
            Nexus.Intelligence.Handlers.RealTimeAnalysisHandler,
            Nexus.Organization.Handlers.RealTimeTenantHandler,
            Nexus.Treasury.Handlers.PolicyNotificationHandler,
            Nexus.Treasury.Handlers.TransferNotificationHandler,
            Nexus.ERP.Handlers.ERPNotificationHandler,
            # --- Process Managers ---
            Nexus.Treasury.ProcessManagers.ReconciliationManager,
            Nexus.Treasury.ProcessManagers.TransferManager,
            Nexus.Payments.ProcessManagers.BulkPaymentSaga
          ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nexus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NexusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
