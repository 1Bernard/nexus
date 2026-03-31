defmodule Nexus.Treasury.NettingSettlementFeatureTest do
  @moduledoc """
  BDD integration test for Netting Settlement Orchestration.
  Ensures that once a cycle is settled, transfers are dispatched and invoices are retired.
  """
  use Cabbage.Feature, file: "treasury/netting_settlement.feature"
  use Nexus.DataCase

  import Commanded.Assertions.EventAssertions
  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Treasury.Commands.{InitializeNettingCycle, AddInvoiceToNetting, SettleNettingCycle}
  alias Nexus.Treasury.Events.{NettingCycleSettled, NettingCycleSettlementCompleted, TransferInitiated}
  alias Nexus.ERP.Events.InvoiceNetted
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all("projection_versions")
      Repo.query!("TRUNCATE event_store.events CASCADE")
    end)

    org_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id, user_id: user_id}}
  end

  # --- Given ---

  defgiven ~r/^an active netting cycle exists for "(?<currency>[^"]+)"$/,
           %{currency: currency},
           %{org_id: org_id, user_id: user_id} = state do
    netting_id = Nexus.Schema.generate_uuidv7()

    cmd = %InitializeNettingCycle{
      netting_id: netting_id,
      org_id: org_id,
      currency: currency,
      period_start: DateTime.utc_now(),
      period_end: DateTime.add(DateTime.utc_now(), 30, :day),
      user_id: user_id
    }

    Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(cmd)
    end)

    {:ok, Map.merge(state, %{netting_id: netting_id, currency: currency})}
  end

  defgiven "the following invoices are added to the cycle:",
           %{table: table},
           %{netting_id: netting_id, org_id: org_id, user_id: user_id} = state do
    invoice_ids =
      Enum.map(table, fn %{subsidiary: subsidiary, amount: amount_str} ->
        invoice_id = Nexus.Schema.generate_uuidv7()
        amount = Decimal.new(amount_str)

        # Ingest the invoice in the ERP domain first
        ingest_cmd = %Nexus.ERP.Commands.IngestInvoice{
          org_id: org_id,
          invoice_id: invoice_id,
          entity_id: "E-#{subsidiary}",
          currency: "EUR",
          amount: amount,
          due_date: Date.utc_today(),
          subsidiary: subsidiary,
          line_items: [%{description: "Netting Item", amount: amount}],
          sap_document_number: "SAP-#{invoice_id}",
          sap_status: "Verified",
          ingested_at: DateTime.utc_now()
        }

        Sandbox.unboxed_run(Repo, fn ->
          assert :ok = App.dispatch(ingest_cmd)
        end)

        cmd = %AddInvoiceToNetting{
          netting_id: netting_id,
          org_id: org_id,
          invoice_id: invoice_id,
          subsidiary: subsidiary,
          amount: amount,
          user_id: user_id
        }

        Sandbox.unboxed_run(Repo, fn ->
          assert :ok = App.dispatch(cmd)
        end)

        invoice_id
      end)

    {:ok, Map.put(state, :invoice_ids, invoice_ids)}
  end

  # --- When ---

  defwhen "the netting cycle is settled",
          _args,
          %{netting_id: netting_id, org_id: org_id, user_id: user_id} = state do
    cmd = %SettleNettingCycle{
      netting_id: netting_id,
      org_id: org_id,
      user_id: user_id
    }

    Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(cmd)
    end)

    # --- MANUAL SAGA DRIVING ---
    # 1. Capture NettingCycleSettled (the trigger)
    {:ok, events} = Nexus.EventStore.read_stream_forward(netting_id)
    settled_event_record = Enum.find(events, fn e -> is_struct(e.data, NettingCycleSettled) end)
    assert settled_event_record, "NettingCycleSettled event not found"

    # 2. Invoke Saga Handle (Pure Function)
    saga_state = %Nexus.Treasury.ProcessManagers.NettingSettlementSaga{}
    commands = Nexus.Treasury.ProcessManagers.NettingSettlementSaga.handle(
      saga_state,
      settled_event_record.data
    )

    # Apply the initial event to the saga state
    saga_state = Nexus.Treasury.ProcessManagers.NettingSettlementSaga.apply(saga_state, settled_event_record.data)

    # 3. Dispatch resulting commands and simulate transfer execution
    Enum.reduce(commands, saga_state, fn saga_cmd, current_state ->
      Sandbox.unboxed_run(Repo, fn ->
        assert :ok = App.dispatch(saga_cmd)
      end)

      case saga_cmd do
        %Nexus.Treasury.Commands.RequestTransfer{transfer_id: t_id} ->
          # Simulate the manual/external process of executing a transfer
          exec_cmd = %Nexus.Treasury.Commands.ExecuteTransfer{
            transfer_id: t_id,
            org_id: org_id,
            executed_at: DateTime.utc_now()
          }

          Sandbox.unboxed_run(Repo, fn ->
            # Assuming it skips authorization for tests if threshold allows, or test handles it.
            App.dispatch(exec_cmd)
          end)

          # Fetch the executed event
          {:ok, t_events} = Nexus.EventStore.read_stream_forward(t_id)
          exec_event = Enum.find(t_events, fn e -> is_struct(e.data, Nexus.Treasury.Events.TransferExecuted) end)

          if exec_event do
             # Feed back into Saga
             new_commands = Nexus.Treasury.ProcessManagers.NettingSettlementSaga.handle(current_state, exec_event.data)

             Enum.each(new_commands, fn cmd ->
               Sandbox.unboxed_run(Repo, fn ->
                 assert :ok = App.dispatch(cmd)
               end)
             end)

             Nexus.Treasury.ProcessManagers.NettingSettlementSaga.apply(current_state, exec_event.data)
          else
             current_state
          end
        _ ->
          current_state
      end
    end)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^a transfer of (?<amount>[^ ]+) should be requested for "(?<subsidiary>[^"]+)"$/,
          %{amount: amount_str, subsidiary: subsidiary},
          %{org_id: org_id} = state do
    expected_amount = Decimal.new(amount_str)

    # In manual mode, we check the transfer aggregate's stream
    # We need to find the transfer_id from the dispatched commands or search all transfers
    # But for simplicity, we can check the event store for TransferInitiated events
    # associated with this org_id.
    {:ok, events} = Nexus.EventStore.read_all_streams_forward()

    transfer_event = Enum.find(events, fn e ->
      is_struct(e.data, TransferInitiated) &&
      e.data.org_id == org_id &&
      e.data.recipient_data.subsidiary == subsidiary &&
      Decimal.equal?(e.data.amount, expected_amount)
    end)

    assert transfer_event, "TransferInitiated event not found for #{subsidiary}"

    {:ok, state}
  end

  defthen "all included invoices should be marked as \"netted\"", _args, %{invoice_ids: ids, org_id: org_id} = state do
    Enum.each(ids, fn id ->
      {:ok, events} = Nexus.EventStore.read_stream_forward(id)
      assert Enum.any?(events, fn e ->
        is_struct(e.data, InvoiceNetted) && e.data.org_id == org_id
      end), "InvoiceNetted event not found for #{id}"
    end)

    {:ok, state}
  end

  defthen "the netting cycle status should be \"settled\"", _args, %{netting_id: netting_id} = state do
    {:ok, events} = Nexus.EventStore.read_stream_forward(netting_id)
    assert Enum.any?(events, fn e ->
      is_struct(e.data, NettingCycleSettlementCompleted)
    end), "NettingCycleSettlementCompleted event not found"

    {:ok, state}
  end
end
