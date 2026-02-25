defmodule Nexus.Organization.Events.InvitationRedeemed do
  @moduledoc """
  Emitted when a user successfully redeems an invitation token to join an organisation.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :invitation_token, :redeemed_by_user_id, :redeemed_at]
  defstruct [:org_id, :invitation_token, :redeemed_by_user_id, :redeemed_at]
end
