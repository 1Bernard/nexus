defmodule Nexus.Payments.Handlers.ExternalPaymentHandler do
  @moduledoc """
  Handler to perform external API calls (side effects) for payments.
  Decoupled from the aggregate to follow Rule 3 (SRP).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Payments.ExternalPaymentHandler",
    consistency: :eventual

  alias Nexus.Payments.Events.ExternalPaymentInitiated
  alias Nexus.Payments.Commands.{SettleExternalPayment, FailExternalPayment}
  alias Nexus.Payments.Gateways.PaystackGateway
  require Logger

  @spec handle(ExternalPaymentInitiated.t(), map()) :: :ok
  def handle(%ExternalPaymentInitiated{} = event, _metadata) do
    Logger.info(
      "[Payments] [Handler] Initiating Paystack transfer for Payment: #{event.payment_id}"
    )

    case PaystackGateway.execute_transfer(
           event.transfer_id,
           event.amount,
           event.currency,
           event.recipient_data
         ) do
      {:ok, external_ref} ->
        Nexus.App.dispatch(%SettleExternalPayment{
          payment_id: event.payment_id,
          org_id: event.org_id,
          external_reference: external_ref,
          settled_at: Nexus.Schema.utc_now()
        })

      {:error, reason} ->
        Nexus.App.dispatch(%FailExternalPayment{
          payment_id: event.payment_id,
          org_id: event.org_id,
          external_reference: nil,
          reason: to_string(reason),
          failed_at: Nexus.Schema.utc_now()
        })
    end

    :ok
  end
end
