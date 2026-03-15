defmodule Nexus.Treasury.ProcessManagers.ReconciliationManager do
  @moduledoc """
  Coordinates matching between ERP invoices and ERP statements.
  Emits commands into the Treasury domain when matches are found.
  Maintains unmatched items isolated per tenant (org_id).
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.ReconciliationManager"

  @derive Jason.Encoder
  defstruct [
    :org_id,
    # invoice_id -> %{amount, currency}
    invoices: %{},
    # statement_line_id -> %{statement_id, amount, currency}
    statement_lines: %{},
    # reconciliation_id -> %{invoice_id, statement_line_id, invoice_data, line_data}
    pending_matches: %{},
    # reconciliation_id -> %{invoice_id, statement_line_id, invoice_data, line_data}
    matched_items: %{}
  ]

  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.ERP.Events.StatementUploaded
  alias Nexus.Treasury.Commands.ReconcileTransaction

  alias Nexus.Treasury.Events.{
    TransactionReconciled,
    ReconciliationProposed,
    ReconciliationRejected,
    ReconciliationReversed
  }

  # Route process managers by org_id so each tenant has an isolated matching engine
  def interested?(%InvoiceIngested{org_id: org_id}), do: {:start, org_id}
  def interested?(%StatementUploaded{org_id: org_id}), do: {:start, org_id}
  def interested?(%TransactionReconciled{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationProposed{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationRejected{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationReversed{org_id: org_id}), do: {:continue!, org_id}
  def interested?(_event), do: false

  # --- Handle Events (Emit Commands) ---

  def handle(%__MODULE__{} = process_manager, %InvoiceIngested{} = event) do
    event_amount =
      if is_binary(event.amount),
        do: Decimal.new(event.amount),
        else: Decimal.new("#{event.amount}")

    # Try to find a matching statement line (negative amount/debit against positive invoice)
    match =
      Enum.find(process_manager.statement_lines, fn {_line_id, line} ->
        line_amount = Decimal.new(line.amount)

        line.currency == event.currency and
          Decimal.eq?(Decimal.abs(line_amount), event_amount) and
          Decimal.lt?(line_amount, 0)
      end)

    if match do
      {line_id, line} = match
      reconciliation_id = Nexus.Schema.generate_uuidv7()
      abs_amount = Decimal.abs(Decimal.new(event.amount))

      %ReconcileTransaction{
        org_id: to_string(event.org_id),
        reconciliation_id: reconciliation_id,
        invoice_id: to_string(event.invoice_id),
        statement_id: to_string(line.statement_id),
        statement_line_id: to_string(line_id),
        amount: abs_amount,
        currency: event.currency,
        actor_email: "system@nexus.ai",
        timestamp: Nexus.Schema.utc_now()
      }
    else
      []
    end
  end

  def handle(%__MODULE__{} = process_manager, %StatementUploaded{} = event) do
    # Try to match newly uploaded statement lines against open invoices
    commands =
      Enum.reduce(event.lines || [], [], fn line, acc ->
        match =
          Enum.find(process_manager.invoices, fn {_invoice_id, invoice} ->
            invoice_amount = Decimal.new(invoice.amount)
            line_amount = Decimal.new(line.amount)

            invoice.currency == line.currency and
              Decimal.eq?(invoice_amount, Decimal.abs(line_amount)) and
              Decimal.lt?(line_amount, 0)
          end)

        id = Map.get(line, :id)

        if match && id do
          {invoice_id, _invoice} = match
          reconciliation_id = Nexus.Schema.generate_uuidv7()
          abs_amount = Decimal.abs(Decimal.new(line.amount))

          match_cmd = %ReconcileTransaction{
            org_id: to_string(event.org_id),
            reconciliation_id: reconciliation_id,
            invoice_id: to_string(invoice_id),
            statement_id: to_string(event.statement_id),
            statement_line_id: to_string(id),
            amount: abs_amount,
            currency: line.currency,
            actor_email: "system@nexus.ai",
            timestamp: Nexus.Schema.utc_now()
          }

          [match_cmd | acc]
        else
          acc
        end
      end)

    Enum.reverse(commands)
  end

  def handle(%__MODULE__{}, %TransactionReconciled{}), do: []
  def handle(%__MODULE__{}, %ReconciliationProposed{}), do: []
  def handle(%__MODULE__{}, %ReconciliationRejected{}), do: []
  def handle(%__MODULE__{}, %ReconciliationReversed{}), do: []
  def handle(%__MODULE__{}, _event), do: []

  # --- Mutate State ---

  def apply(%__MODULE__{} = process_manager, %InvoiceIngested{} = event) do
    amount =
      if is_binary(event.amount),
        do: Decimal.new(event.amount),
        else: Decimal.new("#{event.amount}")

    updated_invoices =
      Map.put(process_manager.invoices || %{}, to_string(event.invoice_id), %{
        amount: amount,
        currency: event.currency
      })

    %__MODULE__{process_manager | org_id: to_string(event.org_id), invoices: updated_invoices}
  end

  def apply(%__MODULE__{} = process_manager, %StatementUploaded{} = event) do
    updated_lines =
      Enum.reduce(event.lines || [], process_manager.statement_lines || %{}, fn line, acc ->
        amount =
          if is_binary(line.amount),
            do: Decimal.new(line.amount),
            else: Decimal.new("#{line.amount}")

        id = Map.get(line, :id)

        if id && !Decimal.eq?(amount, Decimal.new(0)) do
          Map.put(acc, to_string(id), %{
            statement_id: to_string(event.statement_id),
            amount: amount,
            currency: line.currency
          })
        else
          acc
        end
      end)

    %__MODULE__{process_manager | org_id: event.org_id, statement_lines: updated_lines}
  end

  def apply(%__MODULE__{} = process_manager, %TransactionReconciled{} = event) do
    # Ensure items are removed from unmatched lists
    invoices = Map.delete(process_manager.invoices || %{}, event.invoice_id)
    lines = Map.delete(process_manager.statement_lines || %{}, event.statement_line_id)

    # Move from pending to matched if applicable
    pending = Map.delete(process_manager.pending_matches || %{}, event.reconciliation_id)

    # Store in matched_items so we can restore on reversal
    matched =
      Map.put(process_manager.matched_items || %{}, event.reconciliation_id, %{
        invoice_id: event.invoice_id,
        statement_line_id: event.statement_line_id,
        amount: event.amount,
        currency: event.currency
      })

    %__MODULE__{
      process_manager
      | org_id: event.org_id,
        invoices: invoices,
        statement_lines: lines,
        pending_matches: pending,
        matched_items: matched
    }
  end

  def apply(%__MODULE__{} = process_manager, %ReconciliationProposed{} = event) do
    # Remove from unmatched lists while pending
    invoices = Map.delete(process_manager.invoices || %{}, event.invoice_id)
    lines = Map.delete(process_manager.statement_lines || %{}, event.statement_line_id)

    # Store in pending_matches so we can restore on rejection
    pending =
      Map.put(process_manager.pending_matches || %{}, event.reconciliation_id, %{
        invoice_id: event.invoice_id,
        statement_line_id: event.statement_line_id,
        amount: event.amount,
        currency: event.currency
      })

    %__MODULE__{
      process_manager
      | org_id: event.org_id,
        invoices: invoices,
        statement_lines: lines,
        pending_matches: pending
    }
  end

  def apply(%__MODULE__{} = process_manager, %ReconciliationRejected{} = event) do
    # Restore from pending back to unmatched
    case Map.get(process_manager.pending_matches || %{}, event.reconciliation_id) do
      %{invoice_id: invoice_id, statement_line_id: line_id, amount: amount, currency: currency} ->
        invoices =
          Map.put(process_manager.invoices || %{}, invoice_id, %{
            amount: amount,
            currency: currency
          })

        lines =
          Map.put(process_manager.statement_lines || %{}, line_id, %{
            amount: amount,
            currency: currency
          })

        pending = Map.delete(process_manager.pending_matches, event.reconciliation_id)

        %__MODULE__{
          process_manager
          | invoices: invoices,
            statement_lines: lines,
            pending_matches: pending
        }

      nil ->
        process_manager
    end
  end

  def apply(%__MODULE__{} = process_manager, %ReconciliationReversed{} = event) do
    # Restore from matched back to unmatched
    case Map.get(process_manager.matched_items || %{}, event.reconciliation_id) do
      %{invoice_id: invoice_id, statement_line_id: line_id, amount: amount, currency: currency} ->
        invoices =
          Map.put(process_manager.invoices || %{}, invoice_id, %{
            amount: amount,
            currency: currency
          })

        lines =
          Map.put(process_manager.statement_lines || %{}, line_id, %{
            amount: amount,
            currency: currency
          })

        matched = Map.delete(process_manager.matched_items, event.reconciliation_id)

        %__MODULE__{
          process_manager
          | invoices: invoices,
            statement_lines: lines,
            matched_items: matched
        }

      nil ->
        # Fallback if matched_items was empty (historical data)
        # Using event fields if available
        invoices =
          Map.put(process_manager.invoices || %{}, event.invoice_id, %{
            amount: 0,
            currency: "Unknown"
          })

        %__MODULE__{process_manager | invoices: invoices}
    end
  end
end
