defmodule Nexus.Treasury.ProcessManagers.NettingSettlementSaga do
  @moduledoc """
  Coordinates the multi-domain settlement of a netting cycle.
  Reacts to calculation results and dispatches transfers and invoice retirement commands.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.NettingSettlementSaga"

  @derive Jason.Encoder
  defstruct [:netting_id, :org_id, :user_id]
  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Events.{NettingCycleSettled, NettingCycleSettlementCompleted}
  alias Nexus.Treasury.Commands.{RequestTransfer, CompleteNettingCycleSettlement}
  alias Nexus.ERP.Commands.MarkInvoiceAsNetted

  @spec interested?(struct()) :: {:start | :continue!, binary()} | false
  def interested?(%NettingCycleSettled{netting_id: id}), do: {:start, id}
  def interested?(%NettingCycleSettlementCompleted{netting_id: id}), do: {:stop, id}
  def interested?(_event), do: false

  # --- Handle Event (Emit Commands) ---

  @spec handle(t(), struct()) :: [struct()]
  def handle(%__MODULE__{}, %NettingCycleSettled{} = evt) do
    # 1. Dispatch transfers for each subsidiary net position
    transfer_commands =
      Enum.map(evt.net_positions, fn {subsidiary, amount} ->
        # If amount > 0, Subsidiary owes Treasury EUR
        # (This is a simplified assumption for the foundation phase)
        %RequestTransfer{
          transfer_id: Nexus.Schema.generate_uuidv7(),
          org_id: evt.org_id,
          user_id: evt.user_id,
          from_currency: "EUR",
          to_currency: "EUR",
          amount: amount,
          requested_at: DateTime.utc_now(),
          recipient_data: %{
            subsidiary: subsidiary,
            type: "netting_settlement",
            netting_id: evt.netting_id
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

    # 3. Finalize the cycle
    completion_command = %CompleteNettingCycleSettlement{
      netting_id: evt.netting_id,
      org_id: evt.org_id
    }

    transfer_commands ++ invoice_commands ++ [completion_command]
  end

  # --- Mutate State ---

  def apply(%__MODULE__{} = saga, %NettingCycleSettled{} = evt) do
    %__MODULE__{
      saga
      | netting_id: evt.netting_id,
        org_id: evt.org_id,
        user_id: evt.user_id
    }
  end
end
