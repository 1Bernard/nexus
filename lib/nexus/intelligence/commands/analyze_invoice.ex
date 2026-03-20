defmodule Nexus.Intelligence.Commands.AnalyzeInvoice do
  @moduledoc """
  Command to evaluate an invoice for statistical anomalies.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          invoice_id: Types.binary_id(),
          vendor_name: String.t(),
          amount: Types.money(),
          currency: Types.currency(),
          flagged_at: Types.datetime()
        }

  @enforce_keys [
    :analysis_id,
    :org_id,
    :invoice_id,
    :vendor_name,
    :amount,
    :currency,
    :flagged_at
  ]
  defstruct [
    :analysis_id,
    :org_id,
    :invoice_id,
    :vendor_name,
    :amount,
    :currency,
    :flagged_at
  ]
end
