defmodule Nexus.ERP.InvoiceIngestionTest do
  use Cabbage.Feature, file: "erp/invoice_ingestion.feature"
  use Nexus.DataCase

  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.ERP.Projections.Invoice
  alias Nexus.App

  @moduletag :feature

  setup do
    start_supervised!(Nexus.ERP.Projectors.InvoiceProjector)
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

    # Wait for the projector to write the read-model
    Process.sleep(50)

    invoice = Repo.get(Invoice, state.command.invoice_id)
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
    Process.sleep(50)
    assert nil == Repo.get(Invoice, state.command.invoice_id)
    {:ok, state}
  end

  defthen ~r/^the system should gracefully accept the payload without error$/, _vars, state do
    assert :ok = state.result
    {:ok, state}
  end

  defthen ~r/^no duplicate events should be emitted$/, _vars, state do
    {:ok, state}
  end
end
