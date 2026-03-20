defmodule Nexus.ERP.Events.InvoiceMatched do
  @moduledoc """
  Event emitted when an invoice is successfully matched.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          invoice_id: Types.binary_id(),
          org_id: Types.org_id(),
          matched_type: String.t(),
          matched_id: Types.binary_id(),
          matched_at: Types.datetime(),
          actor_email: String.t() | nil
        }

  defstruct [:invoice_id, :org_id, :matched_type, :matched_id, :actor_email, :matched_at]
end
