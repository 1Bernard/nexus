defmodule Nexus.Identity.WebAuthn do
  @callback register(binary(), binary(), any()) :: {:ok, {any(), any()}} | {:error, any()}
  @callback authenticate(binary(), binary(), binary(), binary(), any()) ::
              {:ok, any()} | {:error, any()}
  @callback new_registration_challenge(Keyword.t()) :: any()
  @callback new_authentication_challenge(Keyword.t()) :: any()

  def register(attestation, client_data, challenge) do
    impl().register(attestation, client_data, challenge)
  end

  def authenticate(raw_id, auth_data, sig, client_data, challenge) do
    impl().authenticate(raw_id, auth_data, sig, client_data, challenge)
  end

  def new_registration_challenge(opts \\ []) do
    impl().new_registration_challenge(opts)
  end

  def new_authentication_challenge(opts \\ []) do
    impl().new_authentication_challenge(opts)
  end

  defp impl do
    Application.get_env(:nexus, :webauthn_adapter, Nexus.Identity.WebAuthn.WaxAdapter)
  end
end

defmodule Nexus.Identity.WebAuthn.WaxAdapter do
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
