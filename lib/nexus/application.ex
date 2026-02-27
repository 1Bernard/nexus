defmodule Nexus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Infrastructure (Database & Event Store)
      NexusWeb.Telemetry,
      Nexus.Repo,
      {DNSCluster, query: Application.get_env(:nexus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Nexus.PubSub},
      {Finch, name: Nexus.Finch},

      # 2. Domain Supervisors (The "Monolith" Segregation)
      Nexus.Identity.AuthChallengeStore,
      Nexus.Treasury.Gateways.PriceCache,

      # 3. Commanded Application (Command Dispatcher)
      Nexus.App,

      # 4. Web Transport
      NexusWeb.Endpoint
    ]

    children =
      if Mix.env() == :test do
        children ++
          [
            Nexus.ERP.Projectors.InvoiceProjector,
            Nexus.Treasury.Projectors.ExposureProjector,
            Nexus.Treasury.Handlers.ExposureBridge
          ]
      else
        children ++
          [
            # WebSocket gateway — requires live network; excluded in test env
            Nexus.Treasury.Gateways.PolygonClient,
            Nexus.Identity.Projectors.UserProjector,
            # --- Organization Domain ---
            Nexus.Organization.Projectors.TenantProjector,
            Nexus.Organization.Projectors.InvitationProjector,
            # --- ERP Domain ---
            Nexus.ERP.Projectors.InvoiceProjector,
            # --- Treasury Domain ---
            Nexus.Treasury.Projectors.MarketTickProjector,
            Nexus.Treasury.Projectors.ExposureProjector,
            Nexus.Treasury.Projectors.PolicyProjector,
            # --- Bridge Handlers ---
            Nexus.Treasury.Handlers.ExposureBridge
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
