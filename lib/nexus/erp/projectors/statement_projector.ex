defmodule Nexus.ERP.Projectors.StatementProjector do
  @moduledoc """
  Projects StatementUploaded and StatementRejected events into the
  erp_statements and erp_statement_lines read-model tables.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "ERP.StatementProjector",
    consistency: :strong

  alias Nexus.ERP.Events.{StatementUploaded, StatementRejected}
  alias Nexus.ERP.Projections.{Statement, StatementLine}

  project(%StatementUploaded{} = event, _metadata, fn multi ->
    statement_attrs = %{
      id: event.statement_id,
      org_id: event.org_id,
      filename: event.filename,
      format: event.format,
      status: "uploaded",
      line_count: length(event.lines),
      matched_count: 0,
      content_hash: event.content_hash,
      overlap_warning: exists_similar_statement?(event.org_id, event.filename),
      uploaded_at: Nexus.Schema.parse_datetime(event.uploaded_at)
    }

    multi
    |> Ecto.Multi.insert(:statement, Statement.changeset(%Statement{}, statement_attrs),
      on_conflict: :nothing,
      conflict_target: :id
    )
    |> insert_statement_lines(event.lines, event.statement_id, event.org_id)
  end)

  project(%StatementRejected{} = event, _metadata, fn multi ->
    statement_attrs = %{
      id: event.statement_id,
      org_id: event.org_id,
      filename: event.filename,
      format: "rejected",
      status: "rejected",
      error_message: event.reason,
      uploaded_at: Nexus.Schema.parse_datetime(event.rejected_at)
    }

    multi
    |> Ecto.Multi.insert(:statement, Statement.changeset(%Statement{}, statement_attrs),
      on_conflict: :nothing,
      conflict_target: :id
    )
  end)

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp insert_statement_lines(multi, lines, statement_id, org_id) do
    Enum.with_index(lines, 1)
    |> Enum.reduce(multi, fn {line, idx}, acc ->
      attrs = %{
        id: line.id,
        statement_id: statement_id,
        org_id: org_id,
        date: line.date,
        ref: Map.get(line, :ref, ""),
        amount: line.amount,
        currency: Map.get(line, :currency, ""),
        narrative: Map.get(line, :narrative, ""),
        status: "unmatched",
        metadata: Map.get(line, :metadata, %{})
      }

      Ecto.Multi.insert(
        acc,
        {:line, idx},
        StatementLine.changeset(%StatementLine{}, attrs),
        on_conflict: :nothing,
        conflict_target: :id
      )
    end)
  end

  defp exists_similar_statement?(org_id, filename) do
    import Ecto.Query
    alias Nexus.ERP.Projections.Statement

    from(s in Statement,
      where: s.org_id == ^org_id and s.filename == ^filename,
      select: count(s.id)
    )
    |> Nexus.Repo.one()
    |> Kernel.>(0)
  end
end
