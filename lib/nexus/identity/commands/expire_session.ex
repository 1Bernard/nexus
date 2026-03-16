defmodule Nexus.Identity.Commands.ExpireSession do
  @moduledoc """
  Command to revoke an active user session.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          session_id: Types.binary_id(),
          expired_at: Types.datetime()
        }

  @enforce_keys [:org_id, :user_id, :session_id, :expired_at]
  defstruct [:org_id, :user_id, :session_id, :expired_at]
end
