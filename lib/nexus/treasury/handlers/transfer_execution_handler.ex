defmodule Nexus.Treasury.Handlers.TransferExecutionHandler do
  @moduledoc """
  Coordinates the movement of funds between vaults upon transfer execution.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.TransferExecutionHandler",
    consistency: :strong

  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Treasury.Commands.{DebitVault, CreditVault}
  require Logger

  @spec handle(TransferExecuted.t(), map()) :: :ok
  def handle(%TransferExecuted{} = event, _metadata) do
    # Only synchronize balances if the recipient is a vault (internal or rebalance)
    case event.recipient_data do
      %{"type" => "vault", "vault_id" => to_vault_id} ->
        sync_vaults(event, to_vault_id)

      %{type: "vault", vault_id: to_vault_id} ->
        sync_vaults(event, to_vault_id)

      _ ->
        Logger.info("[Treasury] [Execution] External transfer executed (no vault sync needed).")
        :ok
    end
  end

  defp sync_vaults(event, to_vault_id) do
    # We need the source vault ID. For now, we assume it's provided in recipient_data    # or we'd need to fetch it from the aggregate state.
    # In this implementation, the Transfer aggregate knows the source currency.
    # For a robust solution, we'd need the source_vault_id in the event.
    # For this POC, let's assume if it's internal, the recipient_data has the info.
    from_vault_id = event.recipient_data["from_vault_id"] || event.recipient_data[:from_vault_id]

    if from_vault_id do
      commands = [
        %DebitVault{
          vault_id: from_vault_id,
          org_id: event.org_id,
          amount: event.amount,
          currency: event.from_currency,
          transfer_id: event.transfer_id,
          debited_at: event.executed_at
        },
        %CreditVault{
          vault_id: to_vault_id,
          org_id: event.org_id,
          amount: event.amount,
          currency: event.to_currency,
          transfer_id: event.transfer_id,
          credited_at: event.executed_at
        }
      ]

      Enum.each(commands, fn cmd ->
        case Nexus.App.dispatch(cmd) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error(
              "[Treasury] [Execution] Failed to dispatch vault command: #{inspect(reason)}"
            )
        end
      end)
    else
      Logger.warning(
        "[Treasury] [Execution] Internal transfer executed but 'from_vault_id' is missing."
      )
    end

    :ok
  end
end
