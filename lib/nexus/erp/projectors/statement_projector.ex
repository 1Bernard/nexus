defmodule Nexus.ERP.Projectors.StatementProjector do
  @moduledoc """
  Projects StatementUploaded and StatementRejected events into the
  erp_statements and erp_statement_lines read-model tables.
  Broadcasts to PubSub so StatementLive can update in real time.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "ERP.StatementProjector",
    consistency: :strong

  alias Nexus.ERP.Events.{StatementUploaded, StatementRejected}
  alias Nexus.ERP.Projections.{Statement, StatementLine}

  project(%StatementUploaded{} = ev, _metadata, fn multi ->
    lines = Enum.with_index(ev.lines, 1)

    multi
    |> Ecto.Multi.insert(
      :statement,
      %Statement{
        id: ev.statement_id,
        org_id: ev.org_id,
        filename: ev.filename,
        format: ev.format,
        status: "uploaded",
        line_count: length(ev.lines),
        uploaded_at: parse_datetime(ev.uploaded_at)
      },
      on_conflict: :nothing,
      conflict_target: :id
    )
    |> insert_statement_lines(lines, ev.statement_id, ev.org_id)
  end)

  project(%StatementRejected{} = _ev, _metadata, fn multi ->
    # Rejected statements are not persisted to the read model — they are audit events only.
    multi
  end)

  @impl Commanded.Projections.Ecto
  def after_update(event, _metadata, _changes) do
    case event do
      %StatementUploaded{} ->
        Phoenix.PubSub.broadcast(
          Nexus.PubSub,
          "erp_statements:#{event.org_id}",
          {:statement_uploaded, event.statement_id}
        )

      _ ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp insert_statement_lines(multi, [], _statement_id, _org_id), do: multi

  defp insert_statement_lines(multi, lines, statement_id, org_id) do
    Enum.reduce(lines, multi, fn {line, idx}, acc ->
      Ecto.Multi.insert(
        acc,
        {:line, idx},
        %StatementLine{
          id: line.id,
          statement_id: statement_id,
          org_id: org_id,
          date: line.date,
          ref: Map.get(line, :ref, ""),
          amount: coerce_decimal(line.amount),
          currency: Map.get(line, :currency, ""),
          narrative: Map.get(line, :narrative, ""),
          status: "unmatched"
        },
        on_conflict: :nothing,
        conflict_target: :id
      )
    end)
  end

  defp coerce_decimal(%Decimal{} = d), do: d
  defp coerce_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp coerce_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)

  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
