defmodule Nexus.Identity.Commands.VerifyStepUp do
  @moduledoc """
  Command to verify a secondary biometric factor for a high-value action.
  """
  @enforce_keys [
    :user_id,
    :org_id,
    :challenge_id,
    :action_id,
    :raw_id,
    :authenticator_data,
    :signature,
    :client_data_json
  ]
  defstruct [
    :user_id,
    :org_id,
    :challenge_id,
    :action_id,
    :raw_id,
    :authenticator_data,
    :signature,
    :client_data_json
  ]
end
