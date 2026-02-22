defmodule Nexus.Router do
  @moduledoc """
  The Commanded Router for the Nexus application.
  Dispatches commands to the appropriate domain aggregates.
  """
  use Commanded.Commands.Router

  # Global Middleware Stack
  middleware(Nexus.Shared.Middleware.TenantGate)

  # --- Identity Domain ---
  dispatch(Nexus.Identity.Commands.RegisterUser,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch(Nexus.Identity.Commands.VerifyBiometric,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch(Nexus.Identity.Commands.RegisterSystemAdmin,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  # --- Organization Domain ---
  dispatch(Nexus.Organization.Commands.ProvisionTenant,
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )

  dispatch(Nexus.Organization.Commands.InviteUser,
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )
end
