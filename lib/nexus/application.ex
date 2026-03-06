defmodule Nexus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[Nexus] Application starting in #{Mix.env()} environment")

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
      if Mix.env() == :test do
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
            Nexus.Identity.Projectors.UserRoleProjector,
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
            Nexus.ERP.Handlers.ERPNotificationHandler,
            # --- Process Managers ---
            Nexus.Treasury.ProcessManagers.ReconciliationManager,
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
