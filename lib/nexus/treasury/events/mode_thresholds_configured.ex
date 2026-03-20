defmodule Nexus.Treasury.Events.ModeThresholdsConfigured do
  @moduledoc """
  Event emitted when a system admin configures per-mode transfer thresholds for an organisation.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          mode_thresholds: %{String.t() => Types.money()},
          actor_email: String.t(),
          configured_at: Types.datetime()
        }

  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
end
