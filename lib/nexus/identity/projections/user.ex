defmodule Nexus.Identity.Projections.User do
  @moduledoc """
  The Read-Side projection for the User Identity.
  Used for login lookups and credential verification.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:id, :org_id, :email, :display_name, :status, :role]}
  schema "users" do
    field :org_id, :binary_id
    field :email, :string
    field :display_name, :string
    field :status, :string, default: "active"
    field :cose_key, :binary
    field :credential_id, :binary
    field :role, :string
    field :org_name, :string, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :id,
      :org_id,
      :email,
      :display_name,
      :role,
      :status,
      :cose_key,
      :credential_id
    ])
    |> validate_required([:id, :org_id, :email, :role, :status, :cose_key, :credential_id])
    |> unique_constraint(:credential_id)
    |> unique_constraint(:email)
  end
end
