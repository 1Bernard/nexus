defmodule Nexus.ERP.Events.InvoiceRejected do
  @moduledoc """
  Emitted when an incoming invoice payload is invalid (e.g., negative amount).
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :invoice_id, :reason, :rejected_at]
  defstruct [:org_id, :invoice_id, :reason, :rejected_at]
end
