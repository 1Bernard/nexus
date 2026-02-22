Mix.Task.run("app.start")

alias Nexus.Identity.Projections.User
alias Nexus.Identity.Commands.VerifyBiometric
alias Nexus.Repo

user = Repo.get_by(User, email: "admin@nexus-platform.io")

if user do
  IO.puts("Found Root Admin: #{user.id}")

  # Prepare a challenge in the store
  challenge_id = "test_challenge"
  challenge_bytes = :crypto.strong_rand_bytes(32)
  challenge = %{bytes: challenge_bytes}
  Nexus.Identity.AuthChallengeStore.store_challenge(challenge_id, challenge)

  cmd = %VerifyBiometric{
    user_id: user.id,
    org_id: user.org_id,
    challenge_id: challenge_id,
    raw_id: "fake_id",
    authenticator_data: "fake_data",
    signature: "fake_sig",
    client_data_json: "fake_json"
  }

  case Nexus.App.dispatch(cmd) do
    :ok ->
      IO.puts("✅ Biometric bypass successful for root admin.")
      System.halt(0)

    {:error, reason} ->
      IO.puts("❌ Biometric bypass failed: #{inspect(reason)}")
      System.halt(1)
  end
else
  IO.puts("❌ Root Admin not found in read model.")
  System.halt(1)
end
