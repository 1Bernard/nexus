defmodule Nexus.Schema do
  @moduledoc """
  The Industrial Blueprint for all Nexus Data.

  Every domain (Identity, Treasury, ERP) uses this to ensure:
  1. UUIDv7: For time-ordered primary keys (better for DB performance).
  2. Microsecond Timestamps: Essential for financial audit precision.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      # UUIDv7 is the industry standard for scalable, ordered IDs
      @primary_key {:id, :binary_id, autogenerate: false}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec, inserted_at: :created_at]

      # Multi-tenancy: Every record belongs to an organization.
      # We handle this by explicitly requiring `field :org_id, :binary_id`
      # in every projection schema block (e.g., identity/projections/user.ex).
    end
  end

  def generate_uuidv7, do: Uniq.UUID.uuid7()

  @doc """
  Safely parses a datetime from a binary or returns the DateTime if already parsed.
  Returns DateTime.utc_now() (truncated to seconds) if input is nil or invalid.
  """
  def parse_datetime(%DateTime{} = dt), do: dt |> DateTime.truncate(:microsecond)

  def parse_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} -> dt |> DateTime.truncate(:microsecond)
      {:error, _reason} -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
    end
  end

  def parse_datetime(_), do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
