defmodule Nexus.Identity.Projections.User do
  @moduledoc """
  The Read-Side projection for the User Identity.
  Used for login lookups and credential verification.
  """
  use Nexus.Schema

  schema "users" do
    field :email, :string
    field :role, :string
    field :public_key, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :email, :role, :public_key])
    |> validate_required([:id, :email, :role, :public_key])
  end
end
