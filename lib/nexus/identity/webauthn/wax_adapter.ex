defmodule Nexus.Identity.WebAuthn.WaxAdapter do
  @moduledoc """
  Wax-based implementation of the WebAuthn behavior.
  """
  @behaviour Nexus.Identity.WebAuthn

  def register(attestation, client_data, challenge) do
    Wax.register(attestation, client_data, challenge)
  end

  def authenticate(raw_id, auth_data, sig, client_data, challenge) do
    Wax.authenticate(raw_id, auth_data, sig, client_data, challenge)
  end

  def new_registration_challenge(opts \\ []) do
    Wax.new_registration_challenge(opts)
  end

  def new_authentication_challenge(opts \\ []) do
    Wax.new_authentication_challenge(opts)
  end
end
