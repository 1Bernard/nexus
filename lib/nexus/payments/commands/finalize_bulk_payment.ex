defmodule Nexus.Payments.Commands.FinalizeBulkPayment do
  @moduledoc """
  Internal command used by the saga to complete a bulk batch.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  @primary_key {:bulk_payment_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :org_id, :binary_id
  end

  def changeset(cmd, attrs) do
    cmd
    |> cast(attrs, [:bulk_payment_id, :org_id])
    |> validate_required([:bulk_payment_id, :org_id])
  end
end
