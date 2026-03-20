defmodule Nexus.Organization.Projections.Invitation do
  @moduledoc """
  Read-model projection for an active user invitation to join a Tenant.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :email,
             :role,
             :invited_by,
             :invitation_token,
             :status,
             :invited_at,
             :claimed_at
           ]}
  schema "organization_invitations" do
    field :org_id, :binary_id
    field :email, :string
    field :role, :string, default: "trader"
    field :invited_by, :string
    field :invitation_token, :binary_id
    field :status, :string, default: "pending"
    field :invited_at, :utc_datetime_usec
    field :claimed_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :id,
      :org_id,
      :email,
      :role,
      :invited_by,
      :invitation_token,
      :status,
      :invited_at,
      :claimed_at
    ])
    |> validate_required([:id, :org_id, :email, :role, :invitation_token])
  end
end
