defmodule Nexus.Payments.BulkPaymentOrchestrationFeatureTest do
  @moduledoc """
  Elite BDD tests for Bulk Payment Orchestration Sagas.
  Standardized to Cabbage Gherkin format.
  """
  use Cabbage.Feature, file: "bulk_payment_orchestration.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Payments.ProcessManagers.BulkPaymentSaga
  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Treasury.Events.TransferInitiated
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Payments.Commands.FinalizeBulkPayment
  alias Nexus.ERP.Commands.MatchInvoice

  setup do
    {:ok, %{}}
  end

  # --- Gherkin Steps ---

  defgiven ~r/^a bulk payment batch "(?<id>[^"]+)" is initiated with segments "(?<c1>[^"]+)" and "(?<c2>[^"]+)"$/, %{id: id, c1: c1, c2: c2}, state do
    payments = [
      %{amount: Decimal.new("100.00"), currency: c1},
      %{amount: Decimal.new("200.00"), currency: c2}
    ]

    event = %BulkPaymentInitiated{
      bulk_payment_id: id,
      org_id: "org-1",
      user_id: "user-1",
      payments: payments,
      total_amount: Decimal.new("300.00"),
      count: 2,
      initiated_at: DateTime.utc_now()
    }

    {:ok, Map.merge(state, %{event: event, bulk_payment_id: id})}
  end

  defgiven ~r/^a bulk payment saga for "(?<id>[^"]+)" has "(?<rem>\d+)" remaining item out of "(?<total>\d+)"$/, %{id: id, rem: rem, total: total}, state do
    rem = String.to_integer(rem)
    total = String.to_integer(total)

    saga = %BulkPaymentSaga{
      bulk_payment_id: id,
      org_id: "org-1",
      total_items: total,
      processed_items: total - rem
    }

    {:ok, Map.merge(state, %{saga: saga, bulk_payment_id: id, org_id: "org-1"})}
  end

  defgiven ~r/^a bulk payment batch "(?<id>[^"]+)" includes an item for invoice "(?<inv>[^"]+)"$/, %{id: id, inv: inv}, state do
    payments = [
      %{amount: Decimal.new("100.00"), currency: "EUR", invoice_id: inv}
    ]

    event = %BulkPaymentInitiated{
      bulk_payment_id: id,
      org_id: "org-1",
      user_id: "user-1",
      payments: payments,
      total_amount: Decimal.new("100.00"),
      count: 1,
      initiated_at: DateTime.utc_now()
    }

    {:ok, Map.merge(state, %{event: event, bulk_payment_id: id, invoice_id: inv})}
  end

  defwhen ~r/^the saga processes the initiation event$/, _, %{event: event} = state do
    commands = BulkPaymentSaga.handle(%BulkPaymentSaga{}, event)
    {:ok, Map.put(state, :commands, commands)}
  end

  defwhen ~r/^a transfer is initiated for the final item$/, _, %{saga: saga, bulk_payment_id: id, org_id: org_id} = state do
    event = %TransferInitiated{
      transfer_id: "tx-end",
      org_id: org_id,
      user_id: "user-1",
      from_currency: "EUR",
      to_currency: "USD",
      amount: Decimal.new("100.00"),
      status: :initiated,
      bulk_payment_id: id,
      requested_at: DateTime.utc_now()
    }

    commands = BulkPaymentSaga.handle(saga, event)
    {:ok, Map.put(state, :commands, List.wrap(commands))}
  end

  defthen ~r/^it should dispatch "(?<count>\d+)" individual transfer requests$/, %{count: count}, %{commands: commands} = state do
    count = String.to_integer(count)
    transfers = Enum.filter(commands, &match?(%RequestTransfer{}, &1))
    assert length(transfers) == count
    {:ok, state}
  end

  defthen ~r/^each request should follow the original payment details$/, _, %{commands: commands} = state do
    assert Enum.any?(commands, &(&1.from_currency == "EUR" and Decimal.eq?(&1.amount, Decimal.new("100.00"))))
    assert Enum.any?(commands, &(&1.from_currency == "USD" and Decimal.eq?(&1.amount, Decimal.new("200.00"))))
    {:ok, state}
  end

  defthen ~r/^the saga should dispatch a finalization command for the batch$/, _, %{commands: commands} = state do
    assert Enum.any?(commands, &match?(%FinalizeBulkPayment{}, &1))
    {:ok, state}
  end

  defthen ~r/^it should dispatch both a transfer request and an invoice matching command$/, _, %{commands: commands} = state do
    assert Enum.any?(commands, &match?(%RequestTransfer{}, &1))
    assert Enum.any?(commands, &match?(%MatchInvoice{}, &1))
    {:ok, state}
  end
end
