defmodule Nexus.CrossDomain.Commands.CreateNotification do
  @moduledoc """
  Command to create a new global notification.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id() | nil,
          type: String.t(),
          title: String.t(),
          body: String.t() | nil,
          metadata: map()
        }

  @enforce_keys [:id, :org_id, :type, :title]
  defstruct [:id, :org_id, :user_id, :type, :title, :body, metadata: %{}]
end
