defmodule Nexus.Treasury.Projections.Reconciliation do
  use Nexus.Schema

  @primary_key {:reconciliation_id, :string, autogenerate: false}
  schema "treasury_reconciliations" do
    field :org_id, :string
    field :invoice_id, :string
    field :statement_id, :string
    field :statement_line_id, :string
    field :amount, :decimal
    field :currency, :string
    field :status, Ecto.Enum, values: [:matched, :unmatched]
    field :matched_at, :utc_datetime_usec

    timestamps()
  end
end
