defmodule Nexus.ERP.Aggregates.Statement do
  @moduledoc """
  Aggregate managing bank statement uploads.
  Parses the raw content synchronously and emits StatementUploaded or StatementRejected.
  Idempotency: duplicate statement_id silently returns no events.
  """
  defstruct [:id, :org_id, :status]

  alias Nexus.ERP.Commands.UploadStatement
  alias Nexus.ERP.Events.{StatementUploaded, StatementRejected}
  alias Nexus.ERP.Services.StatementParser

  # Idempotency: already processed
  def execute(%__MODULE__{status: status}, %UploadStatement{}) when not is_nil(status) do
    []
  end

  def execute(%__MODULE__{status: nil}, %UploadStatement{} = cmd) do
    case StatementParser.parse(cmd.format, cmd.raw_content) do
      {:ok, lines} ->
        lines_with_ids =
          Enum.map(lines, fn line ->
            Map.put(line, :id, Nexus.Schema.generate_uuidv7())
          end)

        %StatementUploaded{
          statement_id: cmd.statement_id,
          org_id: cmd.org_id,
          filename: cmd.filename,
          format: cmd.format,
          lines: lines_with_ids,
          uploaded_at: DateTime.utc_now()
        }

      {:error, reason} ->
        %StatementRejected{
          statement_id: cmd.statement_id,
          org_id: cmd.org_id,
          reason: reason,
          rejected_at: DateTime.utc_now()
        }
    end
  end

  def apply(%__MODULE__{} = state, %StatementUploaded{} = ev) do
    %__MODULE__{state | id: ev.statement_id, org_id: ev.org_id, status: :uploaded}
  end

  def apply(%__MODULE__{} = state, %StatementRejected{} = ev) do
    %__MODULE__{state | id: ev.statement_id, org_id: ev.org_id, status: :rejected}
  end
end
