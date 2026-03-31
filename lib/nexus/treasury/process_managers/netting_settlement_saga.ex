defmodule Nexus.Treasury.ProcessManagers.NettingSettlementSaga do
  @moduledoc """
  Coordinates the multi-domain settlement of a netting cycle.
  Reacts to calculation results and dispatches transfers and invoice retirement commands.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.NettingSettlementSaga"

  @derive Jason.Encoder
  defstruct [:netting_id, :org_id, :user_id, :target_currency, :pending_count]
  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Events.{NettingCycleSettled, NettingCycleSettlementCompleted, TransferExecuted}
  alias Nexus.Treasury.Commands.{RequestTransfer, CompleteNettingCycleSettlement}
  alias Nexus.ERP.Commands.MarkInvoiceAsNetted

  @spec interested?(struct()) :: {:start | :continue!, binary()} | false
  def interested?(%NettingCycleSettled{netting_id: id}), do: {:start, id}

  def interested?(%TransferExecuted{recipient_data: data}) do
    case data[:netting_id] || data["netting_id"] do
      nil -> false
      id -> {:continue!, id}
    end
  end

  def interested?(%NettingCycleSettlementCompleted{netting_id: id}), do: {:stop, id}
  def interested?(_event), do: false

  # --- Handle Event (Emit Commands) ---

  @spec handle(t(), struct()) :: [struct()]
  def handle(%__MODULE__{}, %NettingCycleSettled{} = evt) do
    # 1. Dispatch transfers for each subsidiary net position
    transfer_commands =
      Enum.map(evt.net_positions, fn {subsidiary, amount} ->
        %RequestTransfer{
          transfer_id: Nexus.Schema.generate_uuidv7(),
          org_id: evt.org_id,
          user_id: evt.user_id,
          from_currency: evt.target_currency,
          to_currency: evt.target_currency,
          amount: amount,
          requested_at: DateTime.utc_now(),
          recipient_data: %{
            "subsidiary" => subsidiary,
            "type" => "netting_settlement",
            "netting_id" => evt.netting_id
          }
        }
      end)

    # 2. Dispatch invoice retirement commands
    invoice_commands =
      Enum.map(evt.invoice_ids, fn invoice_id ->
        %MarkInvoiceAsNetted{
          invoice_id: invoice_id,
          org_id: evt.org_id,
          netting_id: evt.netting_id
        }
      end)

    transfer_commands ++ invoice_commands
  end

  def handle(%__MODULE__{} = saga, %TransferExecuted{}) do
    # Check if this was our last pending transfer
    if saga.pending_count == 1 do
      [
        %CompleteNettingCycleSettlement{
          netting_id: saga.netting_id,
          org_id: saga.org_id
        }
      ]
    else
      []
    end
  end

  # --- Mutate State ---

  def apply(%__MODULE__{} = saga, %NettingCycleSettled{} = evt) do
    %__MODULE__{
      saga
      | netting_id: evt.netting_id,
        org_id: evt.org_id,
        user_id: evt.user_id,
        target_currency: evt.target_currency,
        pending_count: map_size(evt.net_positions)
    }
  end

  def apply(%__MODULE__{} = saga, %TransferExecuted{}) do
    %__MODULE__{saga | pending_count: saga.pending_count - 1}
  end
end
