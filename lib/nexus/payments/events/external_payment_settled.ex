defmodule Nexus.Payments.Events.ExternalPaymentSettled do
  @moduledoc """
  Emitted when an external payment is successfully settled.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          external_reference: String.t(),
          settled_at: Types.datetime()
        }

  defstruct [:payment_id, :org_id, :external_reference, :settled_at]
end
