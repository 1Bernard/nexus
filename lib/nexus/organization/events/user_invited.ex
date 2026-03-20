defmodule Nexus.Organization.Events.UserInvited do
  @moduledoc """
  Emitted when a new user is invited to a Tenant organization.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          email: String.t(),
          role: String.t(),
          invited_by: String.t(),
          invitation_token: String.t(),
          invited_at: Types.datetime()
        }

  defstruct [:org_id, :email, :role, :invited_by, :invitation_token, :invited_at]
end
