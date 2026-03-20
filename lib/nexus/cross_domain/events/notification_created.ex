defmodule Nexus.CrossDomain.Events.NotificationCreated do
  @moduledoc """
  Event emitted when a new notification is created.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id() | nil,
          type: String.t(),
          title: String.t(),
          body: String.t() | nil,
          metadata: map(),
          timestamp: Types.datetime()
        }
  defstruct [:id, :org_id, :user_id, :type, :title, :body, :metadata, :timestamp]
end
