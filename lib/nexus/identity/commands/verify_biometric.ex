defmodule Nexus.Identity.Commands.VerifyBiometric do
  @moduledoc """
  Command representing the intent to authorize via hardware biometric.
  """
  @enforce_keys [
    :user_id,
    :challenge_id,
    :raw_id,
    :authenticator_data,
    :signature,
    :client_data_json
  ]
  defstruct [:user_id, :challenge_id, :raw_id, :authenticator_data, :signature, :client_data_json]
end
