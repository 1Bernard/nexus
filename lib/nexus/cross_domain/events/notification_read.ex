defmodule Nexus.CrossDomain.Events.NotificationRead do
  @moduledoc """
  Event emitted when a notification is marked as read.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          read_at: Types.datetime()
        }

  @derive Jason.Encoder
  defstruct [:id, :org_id, :user_id, :read_at]
end
