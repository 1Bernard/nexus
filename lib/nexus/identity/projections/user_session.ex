defmodule Nexus.Identity.Projections.UserSession do
  @moduledoc """
  Read model for tracking active security sessions.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :user_id, :user_agent, :ip_address, :last_active_at, :is_expired]}
  schema "identity_user_sessions" do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :session_token, :string
    field :user_agent, :string
    field :ip_address, :string
    field :last_active_at, :utc_datetime_usec
    field :is_expired, :boolean, default: false

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :id,
      :org_id,
      :user_id,
      :session_token,
      :user_agent,
      :ip_address,
      :last_active_at,
      :is_expired
    ])
    |> validate_required([:id, :org_id, :user_id, :session_token])
  end
end
