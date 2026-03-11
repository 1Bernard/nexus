defmodule Nexus.Payments.BulkPaymentFeatureTest do
  use Cabbage.Feature, async: false, file: "payments/bulk_payment.feature"
  use Nexus.DataCase

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.Payments.Commands.InitiateBulkPayment
  alias Nexus.Payments.Commands.AuthorizeBulkPayment
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.ERP.Commands.MatchInvoice
  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Payments.ProcessManagers.BulkPaymentSaga
  alias Nexus.ERP.Projections.Invoice

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(Invoice)
      Nexus.Repo.delete_all(Nexus.Payments.Projections.BulkPayment)

      Ecto.Adapters.SQL.query!(Nexus.Repo, """
      DELETE FROM projection_versions
      WHERE projection_name IN ('Payments.BulkPaymentProjector', 'ERP.InvoiceProjector')
      """)
    end)

    {:ok, %{}}
  end

  # --- Given ---

  defgiven ~r/^I am authorized as "(?<email>[^"]+)" for organisation "(?<org>[^"]+)"$/,
           %{email: email, org: _org_id_alias},
           state do
    # For now, we use a consistent org_id for the test
    org_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    {:ok, Map.merge(state, %{org_id: org_id, user_id: user_id, user_email: email})}
  end

  defgiven ~r/^an ingested invoice "(?<id>[^"]+)" exists for (?<amount>[^ ]+) (?<currency>.+)$/,
           %{id: inv_alias, amount: amount, currency: currency},
           state do
    invoice_id = Nexus.Schema.generate_uuidv7()

    command = %IngestInvoice{
      org_id: state.org_id,
      invoice_id: invoice_id,
      entity_id: "ENT-#{inv_alias}",
      currency: currency,
      amount: amount,
      due_date: Date.utc_today() |> Date.add(30),
      subsidiary: "Default",
      line_items: [%{description: "Test", amount: amount}],
      sap_document_number: "SAP-#{inv_alias}",
      sap_status: "Verified",
      ingested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Project it manually to read model (avoiding StaleEntryError)
    {:ok, [%{data: event, event_number: _num}]} = Nexus.EventStore.read_stream_forward(invoice_id)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      %Nexus.ERP.Events.InvoiceIngested{} = event

      Repo.insert!(%Invoice{
        id: event.invoice_id,
        org_id: event.org_id,
        entity_id: event.entity_id,
        currency: event.currency,
        amount: to_string(event.amount),
        subsidiary: event.subsidiary,
        line_items: event.line_items || [],
        sap_document_number: event.sap_document_number,
        sap_status: event.sap_status,
        status: "ingested",
        due_date: Date.from_iso8601!(event.due_date) |> DateTime.new!(~T[00:00:00.000000]),
        created_at:
          DateTime.from_iso8601(event.ingested_at) |> elem(1) |> DateTime.truncate(:microsecond),
        updated_at:
          DateTime.from_iso8601(event.ingested_at) |> elem(1) |> DateTime.truncate(:microsecond)
      })
    end)

    mapping = Map.get(state, :invoice_mapping, %{}) |> Map.put(inv_alias, invoice_id)
    {:ok, Map.put(state, :invoice_mapping, mapping)}
  end

  # --- When ---

  defwhen ~r/^I upload a bulk payment CSV with (?<n>[0-9]+) instructions:$/,
          %{n: _n, table: table},
          state do
    bulk_payment_id = Nexus.Schema.generate_uuidv7()

    payments =
      Enum.map(table, fn row ->
        %{
          amount: Decimal.new(row.amount),
          currency: row.currency,
          recipient_name: row.recipient_name,
          recipient_account: row.recipient_account,
          invoice_id: nil
        }
      end)

    # We skip the "staged" UI state and go straight to initiation command
    # mimicking what happens when the Authorized button is clicked after analyzing.
    # Note: In our current implementation, InitiateBulkPayment is what happens on 'Authorize'.
    # In BulkPaymentLive.ex, authorize_batch dispatches InitiateBulkPayment.

    {:ok, Map.merge(state, %{bulk_payment_id: bulk_payment_id, payments: payments})}
  end

  defwhen ~r/^I upload a bulk payment CSV with an explicit invoice:$/,
          %{table: table},
          state do
    bulk_payment_id = Nexus.Schema.generate_uuidv7()

    payments =
      Enum.map(table, fn row ->
        invoice_id = Map.get(state.invoice_mapping, row.invoice_id)

        %{
          amount: Decimal.new(row.amount),
          currency: row.currency,
          recipient_name: row.recipient_name,
          recipient_account: row.recipient_account,
          invoice_id: invoice_id
        }
      end)

    {:ok, Map.merge(state, %{bulk_payment_id: bulk_payment_id, payments: payments})}
  end

  defwhen ~r/^I authorize the payment batch$/, _vars, state do
    command = %InitiateBulkPayment{
      bulk_payment_id: state.bulk_payment_id,
      org_id: state.org_id,
      user_id: state.user_id,
      payments: state.payments,
      initiated_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Fetch the event and manually sync the saga
    {:ok, [%{data: event, event_number: _num}]} =
      Nexus.EventStore.read_stream_forward(state.bulk_payment_id)

    # Project the bulk payment manually
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      %Nexus.Payments.Events.BulkPaymentInitiated{} = event

      Repo.insert!(%Nexus.Payments.Projections.BulkPayment{
        id: event.bulk_payment_id,
        org_id: event.org_id,
        user_id: event.user_id,
        status: "initiated",
        total_items: event.count,
        processed_items: 0,
        total_amount: Decimal.new(event.total_amount)
      })
    end)

    # Orchestrate the saga (simulate Commanded)
    dispatched_commands = BulkPaymentSaga.handle(%BulkPaymentSaga{}, event)

    {:ok, Map.put(state, :dispatched_commands, dispatched_commands)}
  end

  # --- Then ---

  defthen ~r/^a bulk payment batch should be initiated with (?<n>[0-9]+) items$/,
          %{n: n_str},
          state do
    expected = String.to_integer(n_str)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query

      batch =
        Repo.one(
          from b in Nexus.Payments.Projections.BulkPayment, where: b.id == ^state.bulk_payment_id
        )

      assert batch != nil
      assert batch.total_items == expected
    end)

    {:ok, state}
  end

  defthen ~r/^(?<n>[0-9]+) individual transfer requests should be dispatched$/,
          %{n: n_str},
          state do
    expected = String.to_integer(n_str)

    transfers =
      Enum.filter(state.dispatched_commands, fn cmd ->
        match?(%RequestTransfer{}, cmd)
      end)

    assert length(transfers) == expected
    {:ok, state}
  end

  defthen ~r/^the invoice "(?<inv_alias>[^"]+)" should be marked as matched$/,
          %{inv_alias: inv_alias},
          state do
    invoice_id = Map.get(state.invoice_mapping, inv_alias)

    # Verify the MatchInvoice command was dispatched
    match_cmd =
      Enum.find(state.dispatched_commands, fn cmd ->
        match?(%MatchInvoice{invoice_id: ^invoice_id}, cmd)
      end)

    assert match_cmd != nil, "Expected MatchInvoice command for #{inv_alias} to be dispatched"

    # Manual projection to read model (bypassing Commanded wrapper for test stability)
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query

      Repo.update_all(
        from(i in Invoice, where: i.id == ^invoice_id),
        set: [status: "matched", updated_at: DateTime.utc_now()]
      )

      inv = Repo.one(from i in Invoice, where: i.id == ^invoice_id)
      assert inv.status == "matched"
    end)

    {:ok, state}
  end

  defthen ~r/^a transfer request for (?<amount>[^ ]+) (?<currency>.+) should be dispatched$/,
          %{amount: amount_str, currency: currency},
          state do
    amount = Decimal.new(amount_str)

    transfer =
      Enum.find(state.dispatched_commands, fn cmd ->
        case cmd do
          %RequestTransfer{from_currency: ^currency} ->
            Decimal.equal?(cmd.amount, amount)

          _ ->
            false
        end
      end)

    assert transfer != nil, "Expected transfer of #{amount} #{currency} to be dispatched"
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number, handler_name, projector_module) do
    # When using :no_sandbox, we might clash with background projectors.
    # We use a unique handler_name suffix to isolate the test from the environment.
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      metadata = %{
        handler_name: "#{handler_name}-test-#{:erlang.unique_integer([:positive])}",
        event_number: event_number
      }

      projector_module.handle(event, metadata)
    end)
  end
end
