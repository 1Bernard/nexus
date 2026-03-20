defmodule Nexus.Identity.WebAuthn.WaxAdapter do
  @moduledoc """
  Wax-based implementation of the WebAuthn behavior.
  """
  @behaviour Nexus.Identity.WebAuthn

  @impl true
  @spec register(binary(), binary(), binary()) :: {:ok, {any(), any()}} | {:error, any()}
  def register(attestation, client_data, challenge) do
    Wax.register(attestation, client_data, challenge)
  end

  @impl true
  @spec authenticate(binary(), binary(), binary(), binary(), any(), list()) ::
          {:ok, any()} | {:error, any()}
  def authenticate(raw_id, auth_data, sig, client_data, challenge, credentials \\ []) do
    Wax.authenticate(raw_id, auth_data, sig, client_data, challenge, credentials)
  end

  @impl true
  @spec new_registration_challenge(Keyword.t()) :: any()
  def new_registration_challenge(opts \\ []) do
    Wax.new_registration_challenge(opts)
  end

  @impl true
  @spec new_authentication_challenge(Keyword.t()) :: any()
  def new_authentication_challenge(opts \\ []) do
    Wax.new_authentication_challenge(opts)
  end
end
