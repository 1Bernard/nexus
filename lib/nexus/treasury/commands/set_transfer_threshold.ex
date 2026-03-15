defmodule Nexus.Treasury.Commands.SetTransferThreshold do
  @moduledoc """
  Command to update the biometric step-up threshold for an organization.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          threshold: Types.money(),
          set_at: Types.datetime()
        }
  @enforce_keys [:policy_id, :org_id, :threshold, :set_at]
  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
