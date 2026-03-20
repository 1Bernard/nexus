defmodule Nexus.Payments.Commands.FailExternalPayment do
  @moduledoc """
  Command to mark an external payment as failed.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          external_reference: String.t() | nil,
          reason: String.t(),
          failed_at: Types.datetime()
        }

  @enforce_keys [:payment_id, :org_id, :reason, :failed_at]
  defstruct [:payment_id, :org_id, :external_reference, :reason, :failed_at]
end
