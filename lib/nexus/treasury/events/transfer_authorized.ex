defmodule Nexus.Treasury.Events.TransferAuthorized do
  @moduledoc """
  Event emitted when a transfer has been authorized (e.g. after step-up).
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id() | nil,
          actor_email: String.t() | nil,
          authorized_at: Types.datetime()
        }

  defstruct [:transfer_id, :org_id, :user_id, :actor_email, :authorized_at]
end
