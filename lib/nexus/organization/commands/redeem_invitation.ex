defmodule Nexus.Organization.Commands.RedeemInvitation do
  @moduledoc """
  Command representing a user's intent to claim an invitation token and join an organisation.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          invitation_token: String.t(),
          redeemed_by_user_id: Types.binary_id(),
          redeemed_at: Types.datetime()
        }

  @enforce_keys [:org_id, :invitation_token, :redeemed_by_user_id, :redeemed_at]
  defstruct [:org_id, :invitation_token, :redeemed_by_user_id, :redeemed_at]
end
