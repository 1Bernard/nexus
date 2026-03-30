defmodule Nexus.CrossDomain.Projections.Notification do
  @moduledoc """
  The Notification projection schema.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :user_id, :type, :title, :body, :metadata, :correlation_id, :causation_id, :read_at]}
  schema "cross_domain_notifications" do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :type, :string
    field :title, :string
    field :body, :string
    field :metadata, :map, default: %{}
    field :correlation_id, :binary_id
    field :causation_id, :binary_id
    field :read_at, :utc_datetime_usec
    field :org_name, :string, virtual: true
    field :user_name, :string, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:id, :org_id, :user_id, :type, :title, :body, :metadata, :correlation_id, :causation_id, :read_at])
    |> validate_required([:id, :org_id, :type, :title])
  end

  @doc """
  Robustly decodes and filters JSONB metadata from events or DB.
  Ensures atom keys and prevents leaking sensitive internal event data.
  """
  @spec decode_metadata(map() | binary() | nil) :: map()
  def decode_metadata(nil), do: %{}

  def decode_metadata(metadata) when is_binary(metadata) do
    metadata |> Jason.decode!() |> decode_metadata()
  end

  def decode_metadata(metadata) when is_map(metadata) do
    # Define allowed keys for public-facing notification metadata
    allowed_keys = ["transfer_id", "invoice_id", "entity_id", "currency", "amount", "sender_name"]

    Enum.reduce(metadata, %{}, fn {key, val}, acc ->
      key_str = to_string(key)
      if key_str in allowed_keys do
        Map.put(acc, String.to_existing_atom(key_str), val)
      else
        acc
      end
    end)
  rescue
    _ -> %{}
  end
end
