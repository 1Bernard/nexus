defmodule Nexus.Identity.AuthChallengeStore do
  @moduledoc """
  High-Performance In-Memory Store for Biometric Handshakes.

  In a real-world app, we don't save 'Temporary Challenges' to a DB.
  It would slow down the system and bloat the audit log.
  We use ETS (Erlang Term Storage) for O(1) speed.

  ## Industrial Placement
  This file belongs in the Identity domain layer: `lib/nexus/identity/`.
  It is supervised by the Identity Domain Supervisor to ensure high availability.
  """
  use GenServer
  require Logger

  @table :auth_challenges

  # --- Client API ---

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Stores a biometric challenge (usually a Wax.Challenge) for a specific session.

  Calculates an expiration timestamp (TTL) to prevent memory leaks,
  which is an essential requirement for SOC2 compliance.
  """
  def store_challenge(session_id, challenge) do
    # TTL of 10 minutes (600s) to tolerate deliberate user interaction / OS prompts
    expires_at = DateTime.utc_now() |> DateTime.add(600, :second)
    :ets.insert(@table, {session_id, challenge, expires_at})

    Logger.debug(
      "[Identity] Challenge stored for session #{session_id} (expires at #{expires_at})"
    )
  end

  @doc """
  Retrieves and immediately deletes the challenge (One-time use).

  This 'Pop' pattern prevents replay attacks by ensuring a
  cryptographic challenge can never be used twice.
  """
  def pop_challenge(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, challenge, expires_at}] ->
        :ets.delete(@table, session_id)
        now = DateTime.utc_now()

        if DateTime.compare(now, expires_at) == :lt do
          Logger.debug("[Identity] Challenge popped successfully for #{session_id}")
          {:ok, challenge}
        else
          Logger.warning(
            "[Identity] Challenge expired for #{session_id} (expired at #{expires_at}, now is #{now})"
          )

          {:error, :expired}
        end

      [] ->
        Logger.error("[Identity] Challenge not found for session #{session_id}")
        {:error, :not_found}
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # Ensure the table is created only if it doesn't exist
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    end

    Logger.info("[Identity] ETS Challenge Store Initialized at #{@table}")
    {:ok, %{}}
  end
end
