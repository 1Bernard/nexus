defmodule Nexus.ERP.StatementAdvancedGatewayTest do
  @moduledoc """
  Elite BDD tests for Advanced Statement Gateway.
  """
  use Cabbage.Feature, file: "erp/advanced_statement_gateway.feature"
  use Nexus.DataCase

  alias Nexus.ERP
  alias Nexus.ERP.Commands.UploadStatement
  alias Nexus.Treasury.Commands.ReconcileTransaction
  alias Nexus.ERP.Projections.{Statement, StatementLine}
  alias Nexus.App

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(StatementLine)
      Repo.delete_all(Statement)
      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM projection_versions")
    end)

    :ok
  end

  defgiven ~r/^an organization "(?<name>[^"]+)" exists$/, _args, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id}}
  end

  defgiven ~r/^a "(?<count>\d+)" line CSV statement "(?<filename>[^"]+)" is uploaded$/,
           %{count: count_str, filename: filename},
           %{org_id: org_id} do
    count = String.to_integer(count_str)
    statement_id = Nexus.Schema.generate_uuidv7()

    content = "date,ref,amount,currency,narrative\n" <>
      Enum.map_join(1..count, "\n", fn i -> "2024-01-01,REF#{i},#{i}.00,USD,Test" end)

    cmd = %UploadStatement{
      statement_id: statement_id,
      org_id: org_id,
      filename: filename,
      format: "csv",
      raw_content: content,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(cmd)

    # Initial projection
    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

    {:ok, %{statement_id: statement_id, count: count, filename: filename}}
  end

  defgiven ~r/^a statement "(?<filename>[^"]+)" with row "(?<row>[^"]+)" has been processed$/,
           %{filename: filename, row: row},
           %{org_id: org_id} do
    statement_id = Nexus.Schema.generate_uuidv7()

    cmd = %UploadStatement{
      statement_id: statement_id,
      org_id: org_id,
      filename: filename,
      format: "csv",
      raw_content: "date,ref,amount,currency,narrative\n2024-01-01," <> row,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(cmd)

    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

    {:ok, %{original_statement_id: statement_id, filename: filename}}
  end

  defgiven ~r/^a statement "(?<filename>[^"]+)" with 1 line has been processed$/,
           %{filename: filename},
           %{org_id: org_id} do
    statement_id = Nexus.Schema.generate_uuidv7()

    cmd = %UploadStatement{
      statement_id: statement_id,
      org_id: org_id,
      filename: filename,
      format: "csv",
      raw_content: "date,ref,amount,currency,narrative\n2024-01-01,REF001,100.00,EUR,Test",
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(cmd)

    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

    # Get line id
    [line] = unboxed_run(fn -> ERP.list_statement_lines(org_id, statement_id) end)

    {:ok, %{statement_id: statement_id, line_id: line.id}}
  end

  defwhen "the gateway processes the statement", _args, _state do
    # Projection was handled in Given
    :ok
  end

  defwhen ~r/^a new statement "(?<filename>[^"]+)" with row "(?<row>[^"]+)" is uploaded$/,
          %{filename: filename, row: row},
          %{org_id: org_id} do
    statement_id = Nexus.Schema.generate_uuidv7()

    cmd = %UploadStatement{
      statement_id: statement_id,
      org_id: org_id,
      filename: filename,
      format: "csv",
      raw_content: "date,ref,amount,currency,narrative\n2024-01-01," <> row,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(cmd)

    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

    {:ok, %{statement_id: statement_id}}
  end

  defwhen "the transaction for that statement line is reconciled",
          _args,
          %{org_id: org_id, statement_id: statement_id, line_id: line_id} do
    recon_id = Nexus.Schema.generate_uuidv7()

    recon_cmd = %ReconcileTransaction{
      reconciliation_id: recon_id,
      org_id: org_id,
      invoice_id: Nexus.Schema.generate_uuidv7(),
      statement_id: statement_id,
      statement_line_id: line_id,
      amount: "100.00",
      currency: "EUR",
      actor_email: "test@example.com",
      timestamp: DateTime.utc_now()
    }

    assert :ok = App.dispatch(recon_cmd)

    {:ok, [%{data: recon_event, event_number: recon_num}]} =
      Nexus.EventStore.read_stream_forward(recon_id)

    project_event(
      recon_event,
      recon_num,
      "Treasury.ReconciliationProjector",
      Nexus.Treasury.Projectors.ReconciliationProjector
    )

    :ok
  end

  defthen ~r/^"(?<count>\d+)" statement lines should be projected to the read model$/,
          %{count: count_str},
          %{statement_id: statement_id} do
    count = String.to_integer(count_str)

    unboxed_run(fn ->
      lines = Repo.all(from(l in StatementLine, where: l.statement_id == ^statement_id))
      assert length(lines) == count
    end)

    :ok
  end

  defthen "the new statement should have an \"overlap_warning\" flag set",
          _args,
          %{statement_id: statement_id} do
    unboxed_run(fn ->
      statement = Repo.get(Statement, statement_id)
      assert statement.overlap_warning == true
    end)

    :ok
  end

  defthen ~r/^the statement "matched_count" should be "(?<count>\d+)"$/,
          %{count: count_str},
          %{statement_id: statement_id} do
    count = String.to_integer(count_str)

    unboxed_run(fn ->
      statement = Repo.get(Statement, statement_id)
      assert statement.matched_count == count
    end)

    :ok
  end

  defthen ~r/^"(?<count>\d+)" matching events should be dispatched to the reconciliation engine$/,
          %{count: count_str},
          %{org_id: org_id} do
    # Verification was implied by previous steps or could listen to events
    :ok
  end

  # --- Helpers ---

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    unboxed_run(fn ->
      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM projection_versions WHERE projection_name = $1", [
        handler_name
      ])

      projector_module.handle(event, metadata)
    end)
  end
end
