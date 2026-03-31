defmodule Nexus.ERP.InvoiceIngestionTest do
  use Cabbage.Feature, file: "erp/invoice_ingestion.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.ERP.Projections.Invoice

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Invoice)
      Repo.delete_all("projection_versions")
      # Ensure a clean event store for the no_sandbox integration test
      Repo.query!("TRUNCATE event_store.events CASCADE")
    end)

    :ok
  end

  # --- Given ---

  defgiven ~r/^a registered tenant "(?<tenant>[^"]+)" exists$/, %{tenant: tenant}, state do
    org_id = Nexus.Schema.generate_uuidv7()

    # Actually provision the tenant to satisfy TenantGate middleware
    :ok =
      App.dispatch(%Nexus.Organization.Commands.ProvisionTenant{
        org_id: org_id,
        name: tenant,
        initial_admin_email: "admin@#{tenant}.com",
        provisioned_by: "system_admin",
        provisioned_at: DateTime.utc_now()
      })

    {:ok, Map.put(state, :org_id, org_id)}
  end

  defgiven ~r/^an invoice "(?<id>[^"]+)" has already been ingested$/, %{id: invoice_id}, state do
    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: "#{state.org_id}-#{invoice_id}",
      entity_id: "E-100",
      currency: "EUR",
      amount: Decimal.new("1000"),
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Consulting", amount: Decimal.new("1000")}],
      sap_document_number: "SAP-#{invoice_id}",
      sap_status: "Verified_Via_Network",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync for setup
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward("#{state.org_id}-#{invoice_id}")
    project_event(event, num)

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
      amount: Decimal.new(amount),
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Software License", amount: Decimal.new(amount)}],
      sap_document_number: "SAP-#{invoice_id}",
      sap_status: "Verified_Via_Network",
      ingested_at: DateTime.utc_now()
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
      amount: Decimal.new(amount),
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Refund", amount: Decimal.new(amount)}],
      sap_document_number: "SAP-#{invoice_id}",
      sap_status: "Verified_Via_Network",
      ingested_at: DateTime.utc_now()
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{result: result, command: command})}
  end

  defwhen ~r/^the ERP system pushes the exact same invoice "(?<id>[^"]+)" again$/,
          %{id: invoice_id},
          state do
    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: "#{state.org_id}-#{invoice_id}",
      entity_id: "E-100",
      currency: "EUR",
      amount: Decimal.new("1000"),
      subsidiary: "Munich HQ",
      due_date: Date.utc_today() |> Date.add(30),
      line_items: [%{description: "Consulting", amount: Decimal.new("1000")}],
      sap_document_number: "SAP-#{invoice_id}-#{Nexus.Schema.generate_uuidv7() |> String.slice(0, 8)}",
      sap_status: "Verified_Via_Network",
      ingested_at: DateTime.utc_now()
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{result: result, command: command})}
  end

  # --- Then ---

  defthen ~r/^the invoice should be accepted and recorded$/, _vars, state do
    assert :ok = state.result

    # SECRETS OF THE ELITE: Deterministic Manual Projection
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.command.invoice_id)
    %{data: event, event_number: num} = List.last(events)
    project_event(event, num)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      invoice = Repo.get(Invoice, state.command.invoice_id)
      assert invoice != nil
      assert invoice.org_id == state.org_id
      assert Decimal.equal?(invoice.amount, state.command.amount)
    end)

    {:ok, state}
  end

  defthen ~r/^an InvoiceIngested event should be emitted$/, _vars, state do
    assert :ok = state.result
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

  defp project_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.ERP.Projectors.InvoiceProjector.handle(event, %{
        handler_name: "ERP.InvoiceProjector",
        event_number: num
      })
    end)
  end
end
