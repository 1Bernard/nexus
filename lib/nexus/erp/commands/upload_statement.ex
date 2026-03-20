defmodule Nexus.ERP.Commands.UploadStatement do
  @moduledoc """
  Command to upload and process a bank statement file.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          statement_id: Types.binary_id(),
          org_id: Types.org_id(),
          filename: String.t(),
          format: String.t(),
          raw_content: String.t(),
          uploaded_at: Types.datetime()
        }

  @enforce_keys [:statement_id, :org_id, :filename, :format, :raw_content, :uploaded_at]
  defstruct [:statement_id, :org_id, :filename, :format, :raw_content, :uploaded_at]
end
