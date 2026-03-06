defmodule Nexus.Payments.Commands.InitiateBulkPayment do
  @moduledoc """
  Command to initiate a batch of payments.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  @primary_key {:bulk_payment_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :org_id, :binary_id
    field :user_id, :binary_id

    embeds_many :payments, PaymentInstruction, primary_key: false do
      field :amount, :decimal
      field :currency, :string
      field :recipient_name, :string
      field :recipient_account, :string
    end
  end

  def changeset(cmd, attrs) do
    cmd
    |> cast(attrs, [:bulk_payment_id, :org_id, :user_id])
    |> cast_embed(:payments, with: &payment_instruction_changeset/2)
    |> validate_required([:bulk_payment_id, :org_id, :user_id, :payments])
  end

  defp payment_instruction_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:amount, :currency, :recipient_name, :recipient_account])
    |> validate_required([:amount, :currency, :recipient_name, :recipient_account])
  end
end
