defmodule Nexus.Organization.Commands.RedeemInvitation do
  @enforce_keys [:org_id, :invitation_token, :redeemed_by_user_id]
  defstruct [:org_id, :invitation_token, :redeemed_by_user_id]
end
