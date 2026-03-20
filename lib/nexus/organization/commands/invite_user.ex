defmodule Nexus.Organization.Commands.InviteUser do
  @moduledoc """
  Dispatched by a Tenant Admin to invite a new user to their organization.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          email: String.t(),
          role: String.t(),
          invited_by: Types.binary_id(),
          invitation_token: String.t(),
          invited_at: Types.datetime()
        }

  @enforce_keys [:org_id, :email, :role, :invited_by, :invitation_token, :invited_at]
  defstruct [:org_id, :email, :role, :invited_by, :invitation_token, :invited_at]
end
