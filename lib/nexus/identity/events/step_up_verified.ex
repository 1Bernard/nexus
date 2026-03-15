defmodule Nexus.Identity.Events.StepUpVerified do
  @moduledoc """
  Event emitted when a secondary biometric verification succeeds.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          action_id: Types.binary_id(),
          verified_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :org_id, :action_id, :verified_at]
  defstruct [:user_id, :org_id, :action_id, :verified_at]
end
