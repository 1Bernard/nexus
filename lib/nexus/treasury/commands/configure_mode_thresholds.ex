defmodule Nexus.Treasury.Commands.ConfigureModeThresholds do
  @moduledoc """
  Command to configure the baseline thresholds for standard, strict, and relaxed modes.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          mode_thresholds: map(),
          actor_email: String.t(),
          configured_at: Types.datetime()
        }

  @enforce_keys [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
end
