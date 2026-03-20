defmodule Nexus.Payments.Events.BulkPaymentCompleted do
  @moduledoc """
  Event emitted when a bulk payment batch is fully processed.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          bulk_payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          completed_at: Types.datetime()
        }

  defstruct [:bulk_payment_id, :org_id, :completed_at]
end
