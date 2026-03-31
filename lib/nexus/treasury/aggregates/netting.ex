defmodule Nexus.Treasury.Aggregates.Netting do
  @moduledoc """
  The Netting aggregate manages the lifecycle of an intercompany netting cycle.
  It tracks which invoices are included and calculates total positions.
  """
  alias Nexus.Treasury.Commands.{InitializeNettingCycle, AddInvoiceToNetting, ScanInvoicesForNetting, SettleNettingCycle, CompleteNettingCycleSettlement}
  alias Nexus.Treasury.Events.{NettingCycleInitialized, NettingCycleScanInitiated, InvoiceAddedToNetting, NettingCycleSettled, NettingCycleSettlementCompleted}

  defstruct [:id, :org_id, :currency, :status, :invoice_ids, :invoice_details, :total_amount]

  # --- Commands ---

  @doc """
  Executes commands against the Netting aggregate.
  1. InitializeNettingCycle: Starts a new intercompany netting process.
  2. AddInvoiceToNetting: Links an ERP invoice to an active cycle.
  3. ScanInvoicesForNetting: Initiates an automated scan for eligible invoices.
  4. SettleNettingCycle: Calculates net positions and initiates global settlement.
  5. CompleteNettingCycleSettlement: Finalizes the cycle after orchestrating transfers.
  """
  def execute(%__MODULE__{id: nil}, %InitializeNettingCycle{} = cmd) do
    %NettingCycleInitialized{
      netting_id: cmd.netting_id,
      org_id: cmd.org_id,
      currency: cmd.currency,
      period_start: cmd.period_start,
      period_end: cmd.period_end,
      user_id: cmd.user_id,
      initialized_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :active} = _netting, %ScanInvoicesForNetting{} = cmd) do
    %NettingCycleScanInitiated{
      netting_id: cmd.netting_id,
      org_id: cmd.org_id,
      user_id: cmd.user_id
    }
  end

  def execute(%__MODULE__{status: :active} = netting, %AddInvoiceToNetting{} = cmd) do
    if Enum.member?(netting.invoice_ids, cmd.invoice_id) do
      {:error, :already_added}
    else
      %InvoiceAddedToNetting{
        netting_id: netting.id,
        org_id: netting.org_id,
        invoice_id: cmd.invoice_id,
        subsidiary: cmd.subsidiary,
        amount: cmd.amount,
        currency: cmd.currency,
        added_at: DateTime.utc_now()
      }
    end
  end

  def execute(%__MODULE__{status: :active} = netting, %SettleNettingCycle{} = cmd) do
    if Enum.empty?(netting.invoice_ids) do
      {:error, :empty_cycle}
    else
      # Calculate net positions per subsidiary in the cycle's target currency
      net_positions =
        netting.invoice_details
        |> Map.values()
        |> Enum.reduce(%{}, fn item, acc ->
          # Convert amount to target currency if necessary
          converted_amount =
            if item.currency == netting.currency do
              item.amount
            else
              # Use the provided fx_rates from the command
              # Rate is assumed to be SOURCE/TARGET (e.g. price of 1 Source in Target)
              rate = Map.get(cmd.fx_rates, "#{item.currency}/#{netting.currency}") || Decimal.new(1)
              Decimal.mult(item.amount, Decimal.new(rate))
            end

          Map.update(acc, item.subsidiary, converted_amount, &Decimal.add(&1, converted_amount))
        end)

      %NettingCycleSettled{
        netting_id: netting.id,
        org_id: netting.org_id,
        user_id: cmd.user_id,
        net_positions: net_positions,
        invoice_ids: netting.invoice_ids,
        target_currency: netting.currency,
        settled_at: DateTime.utc_now()
      }
    end
  end

  def execute(%__MODULE__{status: :settling} = netting, %CompleteNettingCycleSettlement{} = _cmd) do
    %NettingCycleSettlementCompleted{
      netting_id: netting.id,
      org_id: netting.org_id,
      completed_at: DateTime.utc_now()
    }
  end

  def execute(_, _), do: {:error, :invalid_operation}

  # --- State Transitions ---

  def apply(%__MODULE__{} = netting, %NettingCycleInitialized{} = event) do
    %__MODULE__{
      netting
      | id: event.netting_id,
        org_id: event.org_id,
        currency: event.currency,
        status: :active,
        invoice_ids: [],
        invoice_details: %{},
        total_amount: Decimal.new(0)
    }
  end

  def apply(%__MODULE__{} = netting, %NettingCycleScanInitiated{} = _event) do
    netting
  end

  def apply(%__MODULE__{} = netting, %InvoiceAddedToNetting{} = evt) do
    %__MODULE__{netting |
      invoice_ids: [evt.invoice_id | netting.invoice_ids],
      invoice_details: Map.put(netting.invoice_details, evt.invoice_id, %{subsidiary: evt.subsidiary, amount: evt.amount, currency: evt.currency}),
      total_amount: Decimal.add(netting.total_amount, evt.amount)
    }
  end

  def apply(%__MODULE__{} = netting, %NettingCycleSettled{} = _event) do
    %__MODULE__{netting | status: :settling}
  end

  def apply(%__MODULE__{} = netting, %NettingCycleSettlementCompleted{} = _event) do
    %__MODULE__{netting | status: :settled}
  end
end
