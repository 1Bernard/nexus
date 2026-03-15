defmodule Nexus.Treasury.Events.PolicyModeChanged do
  @moduledoc """
  Emitted when an organisation's treasury risk tolerance mode is changed.
  Records the new mode name, corresponding threshold, and timestamp for audit purposes.
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
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :mode, :threshold, :actor_email, :changed_at]
  defstruct [:policy_id, :org_id, :mode, :threshold, :actor_email, :changed_at]
end
