defmodule Nexus.Treasury.Commands.ExecuteTransfer do
  @moduledoc """
  Command to execute an authorized transfer.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          executed_at: Types.datetime()
        }
  @enforce_keys [:transfer_id, :org_id, :executed_at]
  defstruct [:transfer_id, :org_id, :executed_at]
end
