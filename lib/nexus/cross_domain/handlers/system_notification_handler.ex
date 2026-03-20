defmodule Nexus.CrossDomain.Handlers.SystemNotificationHandler do
  @moduledoc """
  Reactive bridge that listens for domain-specific events and creates global notifications.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "CrossDomain.SystemNotificationHandler",
    consistency: :eventual

  alias Nexus.App
  alias Nexus.CrossDomain.Commands.CreateNotification
  alias Nexus.Treasury.Events.{PolicyAlertTriggered, TransferExecuted, PolicyModeChanged}
  alias Nexus.Treasury.Events.ReconciliationProposed
  alias Nexus.ERP.Events.StatementUploaded

  @spec handle(struct(), map()) :: :ok | {:error, any()}
  def handle(%PolicyAlertTriggered{} = event, _metadata) do
    cmd = %CreateNotification{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: event.org_id,
      type: "treasury_alert",
      title: "Policy Alert: #{event.currency_pair}",
      body: "Exposure of #{event.exposure_amount} exceeded threshold of #{event.threshold}.",
      metadata: %{
        currency_pair: event.currency_pair,
        exposure_amount: event.exposure_amount,
        threshold: event.threshold
      }
    }

    App.dispatch(cmd)
  end

  def handle(%TransferExecuted{} = event, _metadata) do
    cmd = %CreateNotification{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: event.org_id,
      type: "transfer_executed",
      title: "Transfer Executed: #{event.from_currency}→#{event.to_currency}",
      body: "#{event.amount} #{event.from_currency} transferred to #{event.to_currency}.",
      metadata: %{
        transfer_id: event.transfer_id,
        from_currency: event.from_currency,
        to_currency: event.to_currency,
        amount: event.amount
      }
    }

    App.dispatch(cmd)
  end

  def handle(%ReconciliationProposed{} = event, _metadata) do
    cmd = %CreateNotification{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: event.org_id,
      type: "reconciliation_proposed",
      title: "Reconciliation Pending Approval",
      body:
        "A #{event.currency} #{event.amount} match requires approval (variance: #{event.variance}).",
      metadata: %{
        reconciliation_id: event.reconciliation_id,
        invoice_id: event.invoice_id,
        variance: event.variance
      }
    }

    App.dispatch(cmd)
  end

  def handle(%PolicyModeChanged{} = event, _metadata) do
    cmd = %CreateNotification{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: event.org_id,
      type: "policy_changed",
      title: "Policy Mode → #{event.mode}",
      body: "Treasury policy changed to #{event.mode} mode by #{event.actor_email}.",
      metadata: %{
        mode: event.mode,
        threshold: event.threshold,
        actor_email: event.actor_email
      }
    }

    App.dispatch(cmd)
  end

  def handle(%StatementUploaded{} = event, _metadata) do
    line_count = length(event.lines)

    cmd = %CreateNotification{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: event.org_id,
      type: "statement_uploaded",
      title: "Statement Uploaded: #{event.filename}",
      body:
        "#{event.format |> String.upcase()} statement with #{line_count} transaction line(s).",
      metadata: %{
        statement_id: event.statement_id,
        filename: event.filename,
        format: event.format,
        line_count: line_count
      }
    }

    App.dispatch(cmd)
  end
end
