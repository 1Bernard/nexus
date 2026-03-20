defmodule Nexus.ERP.Events.InvoiceRejected do
  @moduledoc """
  Emitted when an incoming invoice payload is invalid (e.g., negative amount).
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          invoice_id: Types.binary_id(),
          reason: String.t(),
          rejected_at: Types.datetime()
        }

  defstruct [:org_id, :invoice_id, :reason, :rejected_at]
end
