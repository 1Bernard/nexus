defmodule Nexus.Payments.Events.ExternalPaymentFailed do
  @moduledoc """
  Emitted when an external payment fails.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [:payment_id, :org_id, :external_reference, :reason, :failed_at]

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          external_reference: String.t() | nil,
          reason: String.t(),
          failed_at: Types.datetime()
        }
end
