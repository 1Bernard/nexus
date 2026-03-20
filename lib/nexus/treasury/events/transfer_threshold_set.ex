defmodule Nexus.Treasury.Events.TransferThresholdSet do
  @moduledoc """
  Event emitted when an organisation's biometric transfer threshold is updated.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          threshold: Types.money(),
          set_at: Types.datetime()
        }

  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
