defmodule Nexus.Identity.WebAuthn.MockAdapter do
  @behaviour Nexus.Identity.WebAuthn

  def register(_attestation, _client_data, _challenge) do
    # Simulate valid Wax registration result
    # We need to return {auth_data, result}
    # auth_data.attested_credential_data.credential_public_key
    # auth_data.attested_credential_data.credential_id

    mock_cose_key = %{1 => 2, 3 => -7, -1 => 1, -2 => <<123>>, -3 => <<456>>}
    mock_credential_id = "mock_cred_123"

    auth_data = %{
      attested_credential_data: %{
        credential_public_key: mock_cose_key,
        credential_id: mock_credential_id
      }
    }

    {:ok, {auth_data, %{}}}
  end

  def authenticate(_raw_id, _auth_data, _sig, _client_data, _challenge) do
    {:ok, %{}}
  end

  def new_registration_challenge(opts \\ []) do
    %{
      bytes: "mock_registration_challenge",
      origin: "http://localhost:4000",
      rp_id: Keyword.get(opts, :rp_id, "localhost")
    }
  end

  def new_authentication_challenge(opts \\ []) do
    %{
      bytes: "mock_authentication_challenge",
      origin: "http://localhost:4000",
      rp_id: Keyword.get(opts, :rp_id, "localhost")
    }
  end
end
