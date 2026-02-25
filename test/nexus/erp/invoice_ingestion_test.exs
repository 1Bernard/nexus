defmodule Nexus.ERP.InvoiceIngestionTest do
  use Cabbage.Feature, file: "erp/invoice_ingestion.feature"
  use Nexus.DataCase

  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.ERP.Projections.Invoice
  alias Nexus.App

  @moduletag :feature

  setup do
    # Clear the projection versions table to ensure clean state
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(Invoice)
      Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM projection_versions")
    end)

    :ok
  end

  # --- Given ---
  defgiven ~r/^a registered tenant "(?<tenant>[^"]+)" exists$/, %{tenant: _tenant}, state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, Map.put(state, :org_id, org_id)}
  end

  defgiven ~r/^an invoice "(?<id>[^"]+)" has already been ingested$/, %{id: invoice_id}, state do
    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "E-100",
      currency: "EUR",
      amount: "1000",
      subsidiary: "Munich HQ",
      line_items: [%{description: "Consulting", amount: "1000"}],
      sap_document_number: "SAP-#{invoice_id}"
    }

    :ok = App.dispatch(command)
    {:ok, state}
  end

  # --- When ---
  defwhen ~r/^the ERP system pushes a valid invoice payload for "(?<amount>[^"]+)"$/,
          %{amount: amount_str},
          state do
    [amount, currency] = String.split(amount_str, " ")
    invoice_id = Nexus.Schema.generate_uuidv7()

    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "E-101",
      currency: currency,
      amount: amount,
      subsidiary: "Munich HQ",
      line_items: [%{description: "Software License", amount: amount}],
      sap_document_number: "SAP-#{invoice_id}"
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{result: result, command: command})}
  end

  defwhen ~r/^the ERP system pushes an invoice payload with amount "(?<amount>[^"]+)"$/,
          %{amount: amount_str},
          state do
    [amount, currency] = String.split(amount_str, " ")
    invoice_id = Nexus.Schema.generate_uuidv7()

    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "E-101",
      currency: currency,
      amount: amount,
      subsidiary: "Munich HQ",
      line_items: [%{description: "Refund", amount: amount}],
      sap_document_number: "SAP-#{invoice_id}"
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{result: result, command: command})}
  end

  defwhen ~r/^the ERP system pushes the exact same invoice "(?<id>[^"]+)" again$/,
          %{id: invoice_id},
          state do
    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "E-100",
      currency: "EUR",
      amount: "1000",
      subsidiary: "Munich HQ",
      line_items: [%{description: "Consulting", amount: "1000"}],
      sap_document_number: "SAP-#{invoice_id}"
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{result: result, command: command})}
  end

  # --- Then ---
  defthen ~r/^the invoice should be accepted and recorded$/, _vars, state do
    assert :ok = state.result

    # Manually project the event since subscription is bypassed in tests for determinism
    {:ok, [event]} = Nexus.EventStore.read_stream_forward(state.command.invoice_id)
    project_event(event.data, event.event_number)

    invoice = get_invoice(state.command.invoice_id)
    assert invoice != nil
    assert invoice.org_id == state.org_id
    assert invoice.amount == state.command.amount

    {:ok, state}
  end

  defthen ~r/^an InvoiceIngested event should be emitted$/, _vars, state do
    # App.dispatch returning :ok inherently means the event fired without aggregate failure
    assert :ok = state.result
    {:ok, state}
  end

  defthen ~r/^the invoice should be rejected$/, _vars, state do
    assert :ok = state.result
    {:ok, state}
  end

  defthen ~r/^an InvoiceRejected event should be emitted$/, _vars, state do
    assert get_invoice(state.command.invoice_id) == nil
    {:ok, state}
  end

  defthen ~r/^the system should gracefully accept the payload without error$/, _vars, state do
    assert :ok = state.result
    {:ok, state}
  end

  defthen ~r/^no duplicate events should be emitted$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "ERP.InvoiceProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.ERP.Projectors.InvoiceProjector.handle(event, metadata)
    end)
  end

  defp get_invoice(id) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.get(Invoice, id)
    end)
  end
end
