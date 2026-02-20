defmodule Nexus.Identity.Projections.User do
  @moduledoc """
  The Read-Side projection for the User Identity.
  Used for login lookups and credential verification.
  """
  use Nexus.Schema

  schema "users" do
    field :display_name, :string
    field :role, :string, default: "trader"
    field :cose_key, :binary
    field :credential_id, :binary

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :display_name, :role, :cose_key, :credential_id])
    |> validate_required([:id, :role, :cose_key, :credential_id])
    |> unique_constraint(:credential_id)
  end
end
