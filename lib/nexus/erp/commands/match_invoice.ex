defmodule Nexus.ERP.Commands.MatchInvoice do
  @moduledoc """
  Command to match an invoice to a specific payment or bank transaction.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          invoice_id: Types.binary_id(),
          org_id: Types.org_id(),
          matched_type: String.t(),
          matched_id: Types.binary_id(),
          actor_email: String.t() | nil,
          matched_at: Types.datetime() | nil
        }

  @enforce_keys [:invoice_id, :org_id, :matched_type, :matched_id]
  defstruct [:invoice_id, :org_id, :matched_type, :matched_id, :actor_email, :matched_at]
end
