defmodule Nexus.Payments.Commands.SettleExternalPayment do
  @moduledoc """
  Command to mark an external payment as settled.
  """
  alias Nexus.Types

  defstruct [:payment_id, :org_id, :external_reference, :settled_at]

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          external_reference: String.t(),
          settled_at: Types.datetime()
        }
end
