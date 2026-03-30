defmodule Nexus.Treasury.Aggregates.Netting do
  @moduledoc """
  The Netting aggregate manages the lifecycle of an intercompany netting cycle.
  It tracks which invoices are included and calculates total positions.
  """
  alias Nexus.Treasury.Commands.{InitializeNettingCycle, AddInvoiceToNetting, ScanInvoicesForNetting}
  alias Nexus.Treasury.Events.{NettingCycleInitialized, NettingCycleScanInitiated, InvoiceAddedToNetting}

  defstruct [:id, :org_id, :currency, :status, :invoice_ids, :total_amount]

  # --- Commands ---

  @doc """
  Executes commands against the Netting aggregate.
  1. InitializeNettingCycle: Starts a new intercompany netting process.
  2. AddInvoiceToNetting: Links an ERP invoice to an active cycle.
  3. ScanInvoicesForNetting: Initiates an automated scan for eligible invoices.
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
      # In a real scenario, we'd fetch invoice details from the ERP context.
      # For now, we emit the event which will be handled by the projector.
      %InvoiceAddedToNetting{
        netting_id: netting.id,
        org_id: netting.org_id,
        invoice_id: cmd.invoice_id,
        subsidiary: cmd.subsidiary,
        amount: cmd.amount,
        currency: netting.currency,
        added_at: DateTime.utc_now()
      }
    end
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
        total_amount: Decimal.new(0)
    }
  end

  def apply(%__MODULE__{} = netting, %NettingCycleScanInitiated{} = _event) do
    netting
  end

  def apply(%__MODULE__{} = netting, %InvoiceAddedToNetting{} = evt) do
    %__MODULE__{netting |
      invoice_ids: [evt.invoice_id | netting.invoice_ids],
      total_amount: Decimal.add(netting.total_amount, evt.amount)
    }
  end
end
