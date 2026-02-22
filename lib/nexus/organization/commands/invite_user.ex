defmodule Nexus.Organization.Commands.InviteUser do
  @moduledoc """
  Dispatched by a Tenant Admin to invite a new user to their organization.
  """
  @enforce_keys [:org_id, :email, :role, :invited_by]
  defstruct [:org_id, :email, :role, :invited_by]
end
