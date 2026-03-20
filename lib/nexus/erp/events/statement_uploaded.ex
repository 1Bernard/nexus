defmodule Nexus.ERP.Events.StatementUploaded do
  @moduledoc """
  Emitted when a bank statement is successfully uploaded and parsed.
  """
  alias Nexus.Types
  alias Nexus.ERP.Services.StatementParser

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          statement_id: Types.binary_id(),
          org_id: Types.org_id(),
          filename: String.t(),
          format: String.t(),
          lines: [StatementParser.line()],
          uploaded_at: Types.datetime(),
          content_hash: String.t()
        }

  defstruct [:statement_id, :org_id, :filename, :format, :lines, :uploaded_at, :content_hash]
end
