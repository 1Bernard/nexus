defmodule Nexus.Organization.Commands.RedeemInvitation do
  @moduledoc """
  Command representing a user's intent to claim an invitation token and join an organisation.
  """
  @enforce_keys [:org_id, :invitation_token, :redeemed_by_user_id]
  defstruct [:org_id, :invitation_token, :redeemed_by_user_id]
end
