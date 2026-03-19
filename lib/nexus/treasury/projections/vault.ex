defmodule Nexus.Treasury.Projections.Vault do
  @moduledoc """
  Read model for a physical bank account (Vault).
  """
  use Nexus.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "treasury_vaults" do
    field :org_id, :binary_id
    field :name, :string
    field :bank_name, :string
    field :account_number, :string
    field :iban, :string
    field :currency, :string
    field :balance, :decimal, default: 0
    field :provider, :string
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(vault, attrs) do
    vault
    |> cast(attrs, [:id, :org_id, :name, :bank_name, :account_number, :iban, :currency, :balance, :provider, :status])
    |> validate_required([:id, :org_id, :name, :bank_name, :currency, :provider])
  end
end
