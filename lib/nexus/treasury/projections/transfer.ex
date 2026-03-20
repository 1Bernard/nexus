defmodule Nexus.Treasury.Projections.Transfer do
  @moduledoc """
  Read model for Treasury Transfers.
  Tracks internal vault transfers, external payments, and autonomous rebalancing.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :user_id,
             :from_currency,
             :to_currency,
             :source_vault_id,
             :destination_vault_id,
             :amount,
             :status,
             :type,
             :recipient_data,
             :executed_at,
             :created_at
           ]}
  schema "treasury_transfers" do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :from_currency, :string
    field :to_currency, :string
    field :source_vault_id, :binary_id
    field :destination_vault_id, :binary_id
    field :amount, :decimal
    # "pending", "authorized", "executed", "failed"
    field :status, :string
    # "internal", "external", "rebalance"
    field :type, :string
    field :recipient_data, :map
    field :executed_at, :utc_datetime_usec

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [
      :id,
      :org_id,
      :user_id,
      :from_currency,
      :to_currency,
      :amount,
      :status,
      :type,
      :recipient_data,
      :executed_at
    ])
    |> validate_required([:id, :org_id, :user_id, :from_currency, :amount, :status, :type])
  end
end
