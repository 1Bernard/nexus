defmodule Nexus.Treasury.AutomatedReconciliationTest do
  use Nexus.DataCase, async: false

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.ERP.Commands.UploadStatement
  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  alias Nexus.Treasury.ProcessManagers.ReconciliationManager

  setup do
    org_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Reconciliation)
      Repo.delete_all(StatementLine)
      Repo.delete_all(Invoice)
      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM projection_versions")
    end)

    {:ok, %{org_id: org_id, pm_stream: "AutomatedTest.PM-#{org_id}"}}
  end

  test "automatically reconciles an invoice when a matching statement is uploaded",
       %{org_id: org_id} = state do
    # 1. Ingest an invoice
    invoice_id = Nexus.Schema.generate_uuidv7()

    ingest_cmd = %IngestInvoice{
      org_id: org_id,
      invoice_id: invoice_id,
      entity_id: "ENT-101",
      currency: "EUR",
      amount: "1500.00",
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Service", amount: "1500.00"}],
      sap_document_number: "SAP-101",
      sap_status: "Verified",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(ingest_cmd)

    # Sync PM and Projects
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(invoice_id)
    project_event(event, num, "ERP.InvoiceProjector", Nexus.ERP.Projectors.InvoiceProjector)
    sync_pm(event, state)

    # 2. Upload a matching statement
    statement_id = Nexus.Schema.generate_uuidv7()

    csv_content = """
    date,ref,amount,currency,narrative
    2024-03-02,BANK-REF-101,-1500.00,EUR,Payment for SAP-101
    """

    upload_cmd = %UploadStatement{
      org_id: org_id,
      statement_id: statement_id,
      filename: "statement.csv",
      format: "csv",
      raw_content: csv_content,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(upload_cmd)

    # Sync PM and Projects
    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)
    sync_pm(event, state)

    # 3. Verify reconciliation exists
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      recon = Repo.one(from r in Reconciliation, where: r.invoice_id == ^invoice_id)
      assert recon != nil, "Expected automated reconciliation to be created"
      assert recon.status == :matched
      assert recon.amount == Decimal.new("1500.00")
      assert recon.actor_email == "system@nexus.ai"
      assert recon.org_id == org_id

      # Verify invoice status updated
      inv = Repo.get(Invoice, invoice_id)
      assert inv.status == "matched"
    end)
  end

  test "automatically reconciles a statement line when a matching invoice is ingested",
       %{org_id: org_id} = state do
    # 1. Upload a statement first
    statement_id = Nexus.Schema.generate_uuidv7()

    csv_content = """
    date,ref,amount,currency,narrative
    2024-03-02,BANK-REF-202,-2400.00,USD,Deposit 202
    """

    upload_cmd = %UploadStatement{
      org_id: org_id,
      statement_id: statement_id,
      filename: "statement.csv",
      format: "csv",
      raw_content: csv_content,
      uploaded_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(upload_cmd)

    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward(statement_id)

    project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)
    sync_pm(event, state)

    # 2. Ingest a matching invoice
    invoice_id = Nexus.Schema.generate_uuidv7()

    ingest_cmd = %IngestInvoice{
      org_id: org_id,
      invoice_id: invoice_id,
      entity_id: "ENT-202",
      currency: "USD",
      amount: "2400.00",
      subsidiary: "Tokyo Branch",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Goods", amount: "2400.00"}],
      sap_document_number: "SAP-202",
      sap_status: "Verified",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(ingest_cmd)

    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(invoice_id)
    project_event(event, num, "ERP.InvoiceProjector", Nexus.ERP.Projectors.InvoiceProjector)
    sync_pm(event, state)

    # 3. Verify reconciliation exists
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      recon = Repo.one(from r in Reconciliation, where: r.invoice_id == ^invoice_id)
      assert recon != nil, "Expected automated reconciliation to be created"
      assert recon.status == :matched
      assert recon.actor_email == "system@nexus.ai"
    end)
  end

  # --- Helpers ---

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
    _new_pm_state = ReconciliationManager.apply(pm_state, event)

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
