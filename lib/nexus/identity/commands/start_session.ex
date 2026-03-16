defmodule Nexus.Identity.Commands.StartSession do
  @moduledoc """
  Command to track a new user session.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          session_id: Types.binary_id(),
          session_token: String.t(),
          user_agent: String.t() | nil,
          ip_address: String.t() | nil,
          started_at: Types.datetime()
        }

  @enforce_keys [:org_id, :user_id, :session_id, :session_token, :started_at]
  defstruct [:org_id, :user_id, :session_id, :session_token, :user_agent, :ip_address, :started_at]
end
