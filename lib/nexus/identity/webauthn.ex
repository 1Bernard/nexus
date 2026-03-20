defmodule Nexus.Identity.WebAuthn do
  @moduledoc "Port for WebAuthn integrations."
  @callback register(binary(), binary(), any()) :: {:ok, {any(), any()}} | {:error, any()}
  @callback authenticate(binary(), binary(), binary(), binary(), any(), list()) ::
              {:ok, any()} | {:error, any()}
  @callback new_registration_challenge(Keyword.t()) :: any()
  @callback new_authentication_challenge(Keyword.t()) :: any()

  @doc "Registers a new biometric credential."
  @spec register(binary(), binary(), binary()) :: {:ok, {any(), any()}} | {:error, any()}
  def register(attestation, client_data, challenge) do
    impl().register(attestation, client_data, challenge)
  end

  @doc "Authenticates a biometric credential."
  @spec authenticate(binary(), binary(), binary(), binary(), any(), list()) ::
          {:ok, any()} | {:error, any()}
  def authenticate(raw_id, auth_data, sig, client_data, challenge, credentials \\ []) do
    impl().authenticate(raw_id, auth_data, sig, client_data, challenge, credentials)
  end

  @doc "Generates a new registration challenge."
  @spec new_registration_challenge(Keyword.t()) :: any()
  def new_registration_challenge(opts \\ []) do
    impl().new_registration_challenge(opts)
  end

  @doc "Generates a new authentication challenge."
  @spec new_authentication_challenge(Keyword.t()) :: any()
  def new_authentication_challenge(opts \\ []) do
    impl().new_authentication_challenge(opts)
  end

  defp impl do
    Application.get_env(:nexus, :webauthn_adapter, Nexus.Identity.WebAuthn.WaxAdapter)
  end
end
