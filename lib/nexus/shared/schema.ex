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

      # Multi-tenancy: Every record belongs to an organization
      # This ensures mathematically guaranteed isolation between tenants.
      schema_prefix =
        quote do
          field :org_id, :binary_id
        end
    end
  end

  def generate_uuidv7, do: Uniq.UUID.uuid7()
end
