defmodule Nexus.Identity.Events.SessionExpired do
  @moduledoc """
  Event emitted when a user session is revoked or expires.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          session_id: Types.binary_id(),
          expired_at: Types.datetime()
        }

  defstruct [:org_id, :user_id, :session_id, :expired_at]
end
