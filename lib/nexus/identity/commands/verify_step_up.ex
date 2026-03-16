defmodule Nexus.Identity.Commands.VerifyStepUp do
  @moduledoc """
  Command representing a successful step-up biometric verification.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          challenge_id: Types.binary_id(),
          action_id: Types.binary_id(),
          verified_at: Types.datetime()
        }
  @enforce_keys [:user_id, :org_id, :challenge_id, :action_id, :verified_at]
  defstruct [:user_id, :org_id, :challenge_id, :action_id, :verified_at]
end
