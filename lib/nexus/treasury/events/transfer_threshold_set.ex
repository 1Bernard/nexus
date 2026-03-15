defmodule Nexus.Treasury.Events.TransferThresholdSet do
  @moduledoc """
  Event emitted when an organisation's biometric transfer threshold is updated.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          threshold: Types.money(),
          set_at: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :threshold, :set_at]
  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
