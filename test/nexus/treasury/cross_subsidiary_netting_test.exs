defmodule Nexus.Treasury.CrossSubsidiaryNettingTest do
  @moduledoc """
  BDD integration test for Cross-Subsidiary Netting.
  Verifies that netting cycles can be initialized and invoices consolidated.
  """
  use Cabbage.Feature, file: "treasury/cross_subsidiary_netting.feature"
  use Nexus.DataCase

  import Commanded.Assertions.EventAssertions
  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Treasury.Commands.{InitializeNettingCycle, AddInvoiceToNetting}
  alias Nexus.Treasury.Events.{NettingCycleInitialized, InvoiceAddedToNetting}
  alias Nexus.Treasury.Projections.{NettingCycle, NettingEntry}
  alias Nexus.ERP.Projections.Invoice
  alias Nexus.Treasury.Projectors.NettingProjector
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all("projection_versions")
      Repo.query!("TRUNCATE event_store.events CASCADE")
      Repo.delete_all(NettingCycle)
      Repo.delete_all(NettingEntry)
      Repo.delete_all(Invoice)
    end)

    {:ok, %{}}
  end

  # --- Scenario: Initialize a netting cycle for EUR ---

  defgiven "a registered organization \"Global Corp\" exists", _args, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id, org_name: "Global Corp"}}
  end

  defwhen ~r/^I initialize a netting cycle for "(?<currency>[^"]+)" from "(?<start>[^"]+)" to "(?<end>[^"]+)"$/,
          %{currency: currency, start: start_str, end: end_str},
          %{org_id: org_id} = state do
    netting_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    cmd = %InitializeNettingCycle{
      netting_id: netting_id,
      org_id: org_id,
      currency: currency,
      period_start: Nexus.Schema.parse_datetime(start_str),
      period_end: Nexus.Schema.parse_datetime(end_str),
      user_id: user_id
    }

    Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(cmd)
    end)

    # Manually project the event from the store
    {:ok, [%{data: event} | _]} = Nexus.EventStore.read_stream_forward(netting_id)
    project_event(event, 1)

    {:ok, Map.merge(state, %{netting_id: netting_id, currency: currency})}
  end

  defthen ~r/^a netting cycle should be created in "(?<status>[^"]+)" status$/,
          %{status: status},
          %{netting_id: netting_id} = state do
    cycle = Sandbox.unboxed_run(Repo, fn -> Repo.get!(NettingCycle, netting_id) end)
    assert cycle.status == status
    {:ok, state}
  end

  defthen ~r/^the total netting amount should be "(?<amount>[^"]+)"$/,
          %{amount: amount},
          %{netting_id: netting_id} = state do
    cycle = Sandbox.unboxed_run(Repo, fn -> Repo.get!(NettingCycle, netting_id) end)
    assert Decimal.equal?(cycle.total_amount, Nexus.Schema.parse_decimal(amount))
    {:ok, state}
  end

  # --- Scenario: Consolidate invoices from multiple subsidiaries ---

  defgiven "an active netting cycle for \"EUR\" exists", _args, %{org_id: org_id} = state do
    netting_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    cmd = %InitializeNettingCycle{
      netting_id: netting_id,
      org_id: org_id,
      currency: "EUR",
      period_start: Nexus.Schema.utc_now(),
      period_end: DateTime.add(Nexus.Schema.utc_now(), 30, :day),
      user_id: user_id
    }

    Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(cmd)
    end)

    {:ok, [%{data: event} | _]} = Nexus.EventStore.read_stream_forward(netting_id)
    project_event(event, 1)

    {:ok, Map.merge(state, %{netting_id: netting_id, currency: "EUR", invoices: []})}
  end

  defgiven ~r/^Subsidiary "(?<subsidiary>[^"]+)" has an invoice for "(?<amount>[^"]+) (?<currency>[^"]+)"$/,
           %{subsidiary: subsidiary, amount: amount, currency: _currency},
           state do
    invoice_id = Nexus.Schema.generate_uuidv7()
    {:ok, Map.update!(state, :invoices, &[%{id: invoice_id, subsidiary: subsidiary, amount: amount} | &1])}
  end

  defwhen "I add both invoices to the netting cycle", _args, %{netting_id: netting_id, org_id: org_id, invoices: invoices} = state do
    user_id = Nexus.Schema.generate_uuidv7()

    Enum.each(invoices, fn inv ->
      cmd = %AddInvoiceToNetting{
        netting_id: netting_id,
        org_id: org_id,
        invoice_id: inv.id,
        subsidiary: inv.subsidiary,
        amount: Nexus.Schema.parse_decimal(inv.amount),
        user_id: user_id
      }

      Sandbox.unboxed_run(Repo, fn ->
        assert :ok = App.dispatch(cmd)
      end)
    end)

    # Manually project all adding events from the store
    {:ok, events} = Nexus.EventStore.read_stream_forward(netting_id)
    Enum.each(events, fn %{data: event, event_number: num} ->
      if is_struct(event, InvoiceAddedToNetting) do
        project_event(event, num)
      end
    end)

    {:ok, state}
  end

  defthen ~r/^the cycle should contain "(?<count>[^"]+)" entries$/, %{count: count}, %{netting_id: netting_id} = state do
    entries_count = Sandbox.unboxed_run(Repo, fn ->
      Repo.one(from e in NettingEntry, where: e.netting_id == ^netting_id, select: count(e.id))
    end)
    assert entries_count == String.to_integer(count)
    {:ok, state}
  end

  # --- Scenario: Automate invoice inclusion via scanning ---

  defgiven ~r/^ERP contains "(?<count>\d+)" open invoices for "(?<currency>[^"]+)" within the cycle period$/,
           %{count: count_str, currency: currency},
           %{org_id: org_id} = state do
    count = String.to_integer(count_str)

    invoices =
      Enum.map(1..count, fn i ->
        %{
          id: Nexus.Schema.generate_uuidv7(),
          org_id: org_id,
          entity_id: "ENT-#{i}",
          currency: currency,
          amount: Decimal.new("100.00"),
          subsidiary: "Subsidiary #{i}",
          sap_document_number: "SAP-#{i}",
          due_date: Nexus.Schema.utc_now(),
          status: "ingested"
        }
      end)

    Sandbox.unboxed_run(Repo, fn ->
      Enum.each(invoices, fn inv ->
        Repo.insert!(struct(Invoice, inv))
      end)
    end)

    {:ok, Map.put(state, :scanned_amount, Decimal.new(count * 100))}
  end

  defwhen "I trigger the invoice scan for the cycle", _args, %{netting_id: netting_id, org_id: org_id} = state do
    user_id = Nexus.Schema.generate_uuidv7()

    cmd = %Nexus.Treasury.Commands.ScanInvoicesForNetting{
      netting_id: netting_id,
      org_id: org_id,
      user_id: user_id
    }

    Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(cmd)
    end)

    # In test env, some handlers aren't auto-started (Rule 3).
    # We manually invoke the scanner handler to process the scan.
    {:ok, events} = Nexus.EventStore.read_stream_forward(netting_id)
    scan_initiated = Enum.find(events, fn e -> is_struct(e.data, Nexus.Treasury.Events.NettingCycleScanInitiated) end)
    assert scan_initiated, "ScanInitiated event not found in stream"

    Nexus.Treasury.Handlers.NettingScannerHandler.handle(scan_initiated.data, %{})
    # The scanner will follow and dispatch AddInvoiceToNetting events
    # We need to wait and project those.

    Process.sleep(1000) # Wait for async scanner to dispatch all 3 additions

    {:ok, events} = Nexus.EventStore.read_stream_forward(netting_id)
    Enum.each(events, fn %{data: event, event_number: num} ->
      if is_struct(event, InvoiceAddedToNetting) do
        project_event(event, num)
      end
    end)

    {:ok, state}
  end

  defthen "the total netting amount should be the sum of those invoices", _args, %{netting_id: netting_id, scanned_amount: expected} = state do
    cycle = Sandbox.unboxed_run(Repo, fn -> Repo.get!(NettingCycle, netting_id) end)
    assert Decimal.equal?(cycle.total_amount, expected)
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "Treasury.NettingProjector",
      event_number: event_number
    }

    Sandbox.unboxed_run(Nexus.Repo, fn ->
      NettingProjector.handle(event, metadata)
    end)

    event
  end
end
