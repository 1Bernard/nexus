defmodule Nexus.CrossDomain.Projections.Notification do
  @moduledoc """
  The Notification projection schema.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :user_id, :type, :title, :body, :metadata, :read_at]}
  schema "cross_domain_notifications" do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :type, :string
    field :title, :string
    field :body, :string
    field :metadata, :map, default: %{}
    field :read_at, :utc_datetime_usec
    field :org_name, :string, virtual: true
    field :user_name, :string, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:id, :org_id, :user_id, :type, :title, :body, :metadata, :read_at])
    |> validate_required([:id, :org_id, :type, :title])
  end
end
