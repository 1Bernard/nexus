defmodule Nexus.CrossDomain.Commands.MarkNotificationRead do
  @moduledoc """
  Command to mark a specific notification as read.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id()
        }

  @enforce_keys [:id, :org_id, :user_id]
  defstruct [:id, :org_id, :user_id]
end
