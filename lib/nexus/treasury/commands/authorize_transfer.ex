defmodule Nexus.Treasury.Commands.AuthorizeTransfer do
  @moduledoc """
  Command to authorize a previously initiated pending transfer.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id() | nil,
          actor_email: String.t() | nil,
          authorized_at: Types.datetime()
        }
  @enforce_keys [:transfer_id, :org_id, :authorized_at]
  defstruct [:transfer_id, :org_id, :user_id, :actor_email, :authorized_at]
end
