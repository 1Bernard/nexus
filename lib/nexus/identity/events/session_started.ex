defmodule Nexus.Identity.Events.SessionStarted do
  @moduledoc """
  Event emitted when a new user session is started.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          session_id: Types.binary_id(),
          session_token: String.t(),
          user_agent: String.t() | nil,
          ip_address: String.t() | nil,
          started_at: Types.datetime()
        }

  defstruct [:org_id, :user_id, :session_id, :session_token, :user_agent, :ip_address, :started_at]
end
