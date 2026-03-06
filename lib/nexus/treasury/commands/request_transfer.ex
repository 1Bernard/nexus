defmodule Nexus.Treasury.Commands.RequestTransfer do
  @moduledoc """
  Command to initiate a fund transfer.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  @primary_key {:transfer_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :from_currency, :string
    field :to_currency, :string
    field :amount, :decimal
    # Dynamic threshold for policy enforcement
    field :threshold, :decimal
    # Optional correlation ID for bulk batches
    field :bulk_payment_id, :binary_id
  end

  def changeset(cmd, attrs) do
    cmd
    |> cast(attrs, [
      :transfer_id,
      :org_id,
      :user_id,
      :from_currency,
      :to_currency,
      :amount,
      :threshold,
      :bulk_payment_id
    ])
    |> validate_required([:transfer_id, :org_id, :user_id, :from_currency, :to_currency, :amount])
  end
end
