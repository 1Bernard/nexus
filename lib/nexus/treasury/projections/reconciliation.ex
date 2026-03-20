defmodule Nexus.Treasury.Projections.Reconciliation do
  @moduledoc """
  Read-model schema for the treasury_reconciliations table.
  Tracks the lifecycle of each invoice-to-statement-line match attempt.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :invoice_id,
             :statement_id,
             :statement_line_id,
             :amount,
             :variance,
             :variance_reason,
             :actor_email,
             :currency,
             :status,
             :matched_at
           ]}
  schema "treasury_reconciliations" do
    field :org_id, :binary_id
    field :invoice_id, :binary_id
    field :statement_id, :binary_id
    field :statement_line_id, :binary_id
    field :amount, :decimal
    field :variance, :decimal
    field :variance_reason, :string
    field :actor_email, :string
    field :currency, :string
    field :status, Ecto.Enum, values: [:matched, :unmatched, :reversed, :pending, :rejected]
    field :matched_at, :utc_datetime_usec
    field :org_name, :string, virtual: true

    timestamps()
  end
end
