defmodule Nexus.Treasury.Commands.SetPolicyMode do
  @moduledoc """
  Command to set the named risk tolerance mode for an organisation's treasury policy.
  Valid modes are: "standard", "strict", "relaxed".
  The threshold is derived from the mode and included for aggregate validation.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          mode: String.t(),
          threshold: Types.money(),
          actor_email: String.t(),
          changed_at: Types.datetime()
        }
  @enforce_keys [:policy_id, :org_id, :mode, :threshold, :actor_email, :changed_at]
  defstruct [:policy_id, :org_id, :mode, :threshold, :actor_email, :changed_at]
end
