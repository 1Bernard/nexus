defmodule Nexus.Payments.Events.BulkPaymentInitiated do
  @moduledoc """
  Event emitted when a bulk payment batch is initiated by a user.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          bulk_payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          payments: [map()],
          total_amount: Types.money(),
          count: integer(),
          initiated_at: Types.datetime()
        }

  defstruct [
    :bulk_payment_id,
    :org_id,
    :user_id,
    :payments,
    :total_amount,
    :count,
    :initiated_at
  ]
end
