defmodule Nexus.Organization.Events.InvitationRedeemed do
  @moduledoc """
  Emitted when a user successfully redeems an invitation token to join an organisation.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          invitation_token: String.t(),
          redeemed_by_user_id: Types.binary_id(),
          redeemed_at: Types.datetime()
        }

  defstruct [:org_id, :invitation_token, :redeemed_by_user_id, :redeemed_at]
end
