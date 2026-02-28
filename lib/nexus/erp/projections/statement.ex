defmodule Nexus.ERP.Projections.Statement do
  @moduledoc """
  Read model for uploaded bank statements.
  """
  use Nexus.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "erp_statements" do
    field :org_id, :binary_id
    field :filename, :string
    field :format, :string
    field :status, :string, default: "uploaded"
    field :line_count, :integer, default: 0
    field :uploaded_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(statement, attrs) do
    statement
    |> cast(attrs, [:id, :org_id, :filename, :format, :status, :line_count, :uploaded_at])
    |> validate_required([:id, :org_id, :filename, :format, :status])
    |> validate_inclusion(:format, ~w[mt940 csv])
    |> validate_inclusion(:status, ~w[uploaded rejected])
  end
end
