defmodule Nexus.Identity.Commands.VerifyBiometric do
  @moduledoc """
  Command representing a successful biometric verification.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          challenge_id: Types.binary_id(),
          verified_at: Types.datetime()
        }
  @enforce_keys [:user_id, :org_id, :challenge_id, :verified_at]
  @derive [Jason.Encoder]
  defstruct [:user_id, :org_id, :challenge_id, :verified_at]
end
