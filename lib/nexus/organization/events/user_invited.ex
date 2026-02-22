defmodule Nexus.Organization.Events.UserInvited do
  @moduledoc """
  Emitted when a new user is invited to a Tenant organization.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :email, :role, :invited_by, :invitation_token, :invited_at]
  defstruct [:org_id, :email, :role, :invited_by, :invitation_token, :invited_at]
end
