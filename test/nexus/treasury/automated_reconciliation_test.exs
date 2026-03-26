defmodule Nexus.Treasury.AutomatedReconciliationTest do
  use Cabbage.Feature, file: "treasury/automated_reconciliation.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.ERP.Commands.{IngestInvoice, UploadStatement}
  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  alias Nexus.Treasury.ProcessManagers.ReconciliationManager

  setup do
    org_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Reconciliation)
      Repo.delete_all(StatementLine)
      Repo.delete_all(Invoice)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{org_id: org_id, pm_stream: "AutomatedTest.PM-#{org_id}"}}
  end

  # --- Given ---

  defgiven ~r/^a registered tenant exists$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^an invoice "(?<sap_ref>[^"]+)" for "(?<amount_str>[^"]+)" has been ingested$/,
           %{sap_ref: sap_ref, amount_str: amount_str},
           state do
    [amount, currency] = String.split(amount_str, " ")
    invoice_id = Nexus.Schema.generate_uuidv7()

    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "ENT-101",
      currency: currency,
      amount: amount,
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Service", amount: amount}],
      sap_document_number: sap_ref,
      sap_status: "Verified",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync PM and Projects
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(invoice_id)
    project_event(event, num, "ERP.InvoiceProjector", Nexus.ERP.Projectors.InvoiceProjector)
    sync_pm(event, state)

    {:ok, Map.put(state, :invoice_id, invoice_id)}
  end

  defgiven ~r/^a bank statement is uploaded with a reference "(?<ref>[^"]+)" for "(?<amount_str>[^"]+)"$/,
           %{ref: ref, amount_str: amount_str},
           state do
    upload_statement_helper(state, ref, amount_str)
  end

  # --- When ---

  defwhen ~r/^a bank statement is uploaded with a reference "(?<ref>[^"]+)" for "(?<amount_str>[^"]+)"$/,
          %{ref: ref, amount_str: amount_str},
          state do
    upload_statement_helper(state, ref, amount_str)
  end

  defwhen ~r/^an invoice "(?<sap_ref>[^"]+)" for "(?<amount_str>[^"]+)" is ingested$/,
          %{sap_ref: sap_ref, amount_str: amount_str},
          state do
    [amount, currency] = String.split(amount_str, " ")
    invoice_id = Nexus.Schema.generate_uuidv7()

    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "ENT-202",
      currency: currency,
      amount: amount,
      subsidiary: "Tokyo Branch",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Goods", amount: amount}],
      sap_document_number: sap_ref,
      sap_status: "Verified",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(invoice_id)
    project_event(event, num, "ERP.InvoiceProjector", Nexus.ERP.Projectors.InvoiceProjector)
    sync_pm(event, state)

    {:ok, Map.put(state, :invoice_id, invoice_id)}
  end

  # --- Then ---

  defthen ~r/^the invoice "(?<sap_ref>[^"]+)" should be automatically matched$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      invoice = Repo.get!(Invoice, state.invoice_id)
      assert invoice.status == "matched"
    end)
    {:ok, state}
  end

  defthen ~r/^the statement reference "(?<ref>[^"]+)" should be automatically matched$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      line = Repo.one(from l in StatementLine, where: l.statement_id == ^state.statement_id)
      assert line.status == "matched"
    end)
    {:ok, state}
  end

  defthen ~r/^a reconciliation record should exist with status "matched"$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      recon = Repo.one(from r in Reconciliation, where: r.invoice_id == ^state.invoice_id)
      assert recon != nil
      assert recon.status == :matched
    end)
    {:ok, state}
  end

  # --- Helpers ---

  defp upload_statement_helper(state, ref, amount_str) do
    [amount, currency] = String.split(amount_str, " ")
    statement_id = Nexus.Schema.generate_uuidv7()

    csv_content = """
    date,ref,amount,currency,narrative
    #{Date.utc_today()},#{ref},#{amount},#{currency},Payment for Invoice
    """

    command = %UploadStatement{
      org_id: state.org_id,
      statement_id: statement_id,
      filename: "statement.csv",
      format: "csv",
      raw_content: csv_content,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync PM and Projects
    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)
    sync_pm(event, state)

    {:ok, Map.put(state, :statement_id, statement_id)}
  end

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      projector_module.handle(event, metadata)
    end)
  end

  defp sync_pm(event, state) do
    # Replay PM state
    pm_state =
      case Nexus.EventStore.read_stream_forward(state.pm_stream) do
        {:ok, events} ->
          Enum.reduce(events, %ReconciliationManager{}, fn %{data: e}, acc ->
            ReconciliationManager.apply(acc, e)
          end)

        _ ->
          %ReconciliationManager{}
      end

    # Handle event (emit commands)
    case ReconciliationManager.handle(pm_state, event) do
      [] -> :ok
      command when is_struct(command) -> dispatch_and_project(command)
      commands when is_list(commands) -> Enum.each(commands, &dispatch_and_project/1)
    end

    # Persist PM state change
    event_data = %EventStore.EventData{
      event_type: to_string(event.__struct__),
      data: event,
      metadata: %{}
    }

    Nexus.EventStore.append_to_stream(state.pm_stream, :any_version, [event_data])
  end

  defp dispatch_and_project(command) do
    assert :ok = App.dispatch(command)
    recon_id = command.reconciliation_id
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(recon_id)

    project_event(
      event,
      num,
      "Treasury.ReconciliationProjector",
      Nexus.Treasury.Projectors.ReconciliationProjector
    )
  end
end
