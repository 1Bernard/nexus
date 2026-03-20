defmodule Nexus.ERP.Projections.Statement do
  @moduledoc """
  Read model for uploaded bank statements.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :filename,
             :format,
             :status,
             :line_count,
             :matched_count,
             :overlap_warning,
             :content_hash,
             :uploaded_at,
             :error_message
           ]}
  schema "erp_statements" do
    field :org_id, :binary_id
    field :filename, :string
    field :format, :string
    field :status, :string, default: "uploaded"
    field :line_count, :integer, default: 0
    field :matched_count, :integer, default: 0
    field :overlap_warning, :boolean, default: false
    field :content_hash, :string
    field :uploaded_at, :utc_datetime_usec
    field :error_message, :string
    field :org_name, :string, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(statement, attrs) do
    statement
    |> cast(attrs, [
      :id,
      :org_id,
      :filename,
      :format,
      :status,
      :line_count,
      :matched_count,
      :overlap_warning,
      :uploaded_at,
      :error_message,
      :content_hash
    ])
    |> validate_required([:id, :org_id, :filename, :format, :status])
    |> validate_inclusion(:format, ~w[mt940 csv rejected])
    |> validate_inclusion(:status, ~w[uploaded rejected])
  end
end
