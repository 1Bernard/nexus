defmodule Nexus.Payments.Commands.FinalizeBulkPayment do
  @moduledoc """
  Internal command used by the saga to complete a bulk batch.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          bulk_payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          completed_at: Types.datetime()
        }

  @enforce_keys [:bulk_payment_id, :org_id, :completed_at]
  defstruct [:bulk_payment_id, :org_id, :completed_at]
end
