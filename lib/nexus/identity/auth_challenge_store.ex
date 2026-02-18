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
  Stores a biometric challenge for a specific session.

  Calculates an expiration timestamp (TTL) to prevent memory leaks,
  which is an essential requirement for SOC2 compliance.
  """
  def store_challenge(session_id, challenge) do
    # TTL of 60 seconds is industry standard for WebAuthn
    expires_at = DateTime.utc_now() |> DateTime.add(60, :second)
    :ets.insert(@table, {session_id, challenge, expires_at})
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
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, challenge}
        else
          {:error, :expired}
        end

      [] -> {:error, :not_found}
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # We create the table here. If the process crashes, the supervisor restarts it.
    # {read_concurrency: true} is used for high-performance concurrent lookups.
    :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    Logger.info("[Identity] ETS Challenge Store Initialized at #{@table}")
    {:ok, %{}}
  end
end
