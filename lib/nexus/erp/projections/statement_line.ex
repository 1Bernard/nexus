defmodule Nexus.ERP.Projections.StatementLine do
  @moduledoc """
  Read model for individual transaction lines parsed from an uploaded bank statement.
  """
  use Nexus.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "erp_statement_lines" do
    field :statement_id, :binary_id
    field :org_id, :binary_id
    field :date, :string
    field :ref, :string
    field :amount, :decimal
    field :currency, :string
    field :narrative, :string
    field :status, :string, default: "unmatched"
    field :error_message, :string
    field :metadata, :map, default: %{}
    field :org_name, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :id,
      :statement_id,
      :org_id,
      :date,
      :ref,
      :amount,
      :currency,
      :narrative,
      :status,
      :error_message,
      :metadata
    ])
    |> validate_required([:id, :statement_id, :org_id, :date, :amount])
  end
end
