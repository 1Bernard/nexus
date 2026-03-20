defmodule Nexus.ERP.Events.StatementRejected do
  @moduledoc """
  Emitted when an uploaded statement file cannot be parsed (empty, wrong format, unreadable).
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          statement_id: Types.binary_id(),
          org_id: Types.org_id(),
          filename: String.t(),
          reason: String.t(),
          rejected_at: Types.datetime()
        }

  defstruct [:statement_id, :org_id, :filename, :reason, :rejected_at]
end
