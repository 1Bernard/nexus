defmodule Nexus.Identity.Projections.UserSettings do
  @moduledoc """
  Read model for user-specific preferences and localization.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:org_id, :user_id, :locale, :timezone, :notifications_enabled]}
  schema "identity_user_settings" do
    field :user_id, :binary_id
    field :org_id, :binary_id
    field :locale, :string, default: "en"
    field :timezone, :string, default: "UTC"
    field :notifications_enabled, :boolean, default: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:org_id, :user_id, :locale, :timezone, :notifications_enabled])
    |> validate_required([:org_id, :user_id])
  end
end
