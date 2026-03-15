defmodule Nexus.Treasury.Events.TransferAuthorized do
  @moduledoc """
  Event emitted when a transfer has been authorized (e.g. after step-up).
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          actor_email: String.t() | nil,
          authorized_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [:transfer_id, :org_id, :authorized_at]
  defstruct [:transfer_id, :org_id, :actor_email, :authorized_at]
end
