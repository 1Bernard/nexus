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
    # Primary data store: id -> %{amount, currency, ...}
    invoices: %{},
    statement_lines: %{},
    # O(1) Indices: currency -> amount_str -> [id]
    invoice_index: %{},
    line_index: %{},
    # Reconciliation tracking
    pending_matches: %{},
    matched_items: %{},
    transfers: %{}
  ]

  @type t :: %__MODULE__{}

  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.ERP.Events.StatementUploaded
  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Treasury.Commands.ReconcileTransaction

  alias Nexus.Treasury.Events.{
    TransactionReconciled,
    ReconciliationProposed,
    ReconciliationRejected,
    ReconciliationReversed
  }

  # Route process managers by org_id so each tenant has an isolated matching engine
  @spec interested?(struct()) :: {:start | :continue!, binary()} | false
  def interested?(%InvoiceIngested{org_id: org_id}), do: {:start, org_id}
  def interested?(%StatementUploaded{org_id: org_id}), do: {:start, org_id}
  def interested?(%TransferExecuted{org_id: org_id}), do: {:start, org_id}
  def interested?(%TransactionReconciled{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationProposed{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationRejected{org_id: org_id}), do: {:continue!, org_id}
  def interested?(%ReconciliationReversed{org_id: org_id}), do: {:continue!, org_id}
  def interested?(_event), do: false

  # --- Handle Events (Emit Commands) ---

  @spec handle(t(), struct()) :: [struct()] | struct() | []
  def handle(%__MODULE__{} = pm, %InvoiceIngested{} = event) do
    amount = Nexus.Schema.parse_decimal(event.amount)

    # Try O(1) match in statement lines first
    with [] <- find_matching_statement_lines(pm, event, amount),
         [] <- find_matching_transfers(pm, event, amount) do
      []
    else
      [cmd | _] -> cmd
      cmd -> cmd
    end
  end

  def handle(%__MODULE__{} = pm, %StatementUploaded{} = event) do
    Enum.flat_map(event.lines || [], fn line ->
      id = to_string(Map.get(line, :id))
      amount = Nexus.Schema.parse_decimal(line.amount)

      # Search for positive invoice (credit) that matches negative statement line
      search_amount = Decimal.abs(amount)
      key = amount_to_index_key(search_amount)

      case get_in(pm.invoice_index || %{}, [line.currency, key]) do
        [invoice_id | _] ->
          [build_reconcile_command(pm.org_id, invoice_id, id, event.statement_id, search_amount, line.currency)]
        _ -> []
      end
    end)
  end

  def handle(%__MODULE__{} = pm, %TransferExecuted{} = event) do
    amount = Nexus.Schema.parse_decimal(event.amount)
    key = amount_to_index_key(amount)

    # Try O(1) match across invoices
    case get_in(pm.invoice_index || %{}, [event.from_currency, key]) do
      [invoice_id | _] ->
        build_reconcile_command(pm.org_id, invoice_id, event.transfer_id, "TRANSFER-#{event.transfer_id}", amount, event.from_currency)
      _ -> []
    end
  end

  def handle(%__MODULE__{}, %TransactionReconciled{}), do: []
  def handle(%__MODULE__{}, %ReconciliationProposed{}), do: []
  def handle(%__MODULE__{}, %ReconciliationRejected{}), do: []
  def handle(%__MODULE__{}, %ReconciliationReversed{}), do: []
  def handle(%__MODULE__{}, _event), do: []

  # --- Handle Helpers ---

  defp find_matching_statement_lines(pm, event, amount) do
    # Search for negative amount line (debit) that matches positive invoice
    search_amount = Decimal.negate(amount)
    key = amount_to_index_key(search_amount)

    case get_in(pm.line_index || %{}, [event.currency, key]) do
      [line_id | _] ->
        line = pm.statement_lines[line_id]
        build_reconcile_command(pm.org_id, event.invoice_id, line_id, line.statement_id, amount, event.currency)
      _ -> []
    end
  end

  defp find_matching_transfers(pm, event, amount) do
    match = Enum.find(pm.transfers || %{}, fn {_id, t} ->
      t.currency == event.currency && Decimal.eq?(t.amount, amount)
    end)

    case match do
      {transfer_id, _t} ->
        build_reconcile_command(pm.org_id, event.invoice_id, transfer_id, "TRANSFER-#{transfer_id}", amount, event.currency)
      _ -> []
    end
  end

  defp build_reconcile_command(org_id, invoice_id, line_id, statement_id, amount, currency) do
    %ReconcileTransaction{
      org_id: to_string(org_id),
      reconciliation_id: Nexus.Schema.generate_uuidv7(),
      invoice_id: to_string(invoice_id),
      statement_id: to_string(statement_id),
      statement_line_id: to_string(line_id),
      amount: Decimal.abs(amount),
      currency: currency,
      actor_email: "system@nexus.ai",
      timestamp: Nexus.Schema.utc_now()
    }
  end

  # --- Mutate State ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = pm, %InvoiceIngested{} = event) do
    id = to_string(event.invoice_id)
    amount = Nexus.Schema.parse_decimal(event.amount)

    # 1. Update primary store
    pm = %{pm |
      org_id: to_string(event.org_id),
      invoices: Map.put(pm.invoices || %{}, id, %{amount: amount, currency: event.currency})
    }

    # 2. Update index
    %{pm | invoice_index: index_add(pm.invoice_index, event.currency, amount, id)}
  end

  def apply(%__MODULE__{} = pm, %StatementUploaded{} = event) do
    # 1. Update primary store and index for each line
    {lines, index} =
      Enum.reduce(event.lines || [], {pm.statement_lines || %{}, pm.line_index || %{}}, fn line, {l_acc, i_acc} ->
        id = to_string(Map.get(line, :id))
        amount = Nexus.Schema.parse_decimal(line.amount)

        if id != "nil" && !Decimal.eq?(amount, Decimal.new(0)) do
          l_acc = Map.put(l_acc, id, %{
            statement_id: to_string(event.statement_id),
            amount: amount,
            currency: line.currency
          })
          i_acc = index_add(i_acc, line.currency, amount, id)
          {l_acc, i_acc}
        else
          {l_acc, i_acc}
        end
      end)

    %__MODULE__{pm | org_id: event.org_id, statement_lines: lines, line_index: index}
  end

  def apply(%__MODULE__{} = pm, %TransferExecuted{} = event) do
    id = to_string(event.transfer_id)
    amount = Nexus.Schema.parse_decimal(event.amount)

    updated_transfers =
      Map.put(pm.transfers || %{}, id, %{
        amount: amount,
        currency: event.from_currency,
        recipient_data: event.recipient_data
      })

    %__MODULE__{pm | org_id: to_string(event.org_id), transfers: updated_transfers}
  end

  def apply(%__MODULE__{} = pm, %TransactionReconciled{} = event) do
    # Remove from unmatched lists and indices
    {invoices, i_index} = case Map.pop(pm.invoices || %{}, event.invoice_id) do
      {nil, acc} -> {acc, pm.invoice_index}
      {inv, acc} -> {acc, index_remove(pm.invoice_index, inv.currency, inv.amount, event.invoice_id)}
    end

    {lines, l_index} = case Map.pop(pm.statement_lines || %{}, event.statement_line_id) do
      {nil, acc} -> {acc, pm.line_index}
      {line, acc} -> {acc, index_remove(pm.line_index, line.currency, line.amount, event.statement_line_id)}
    end

    transfers = Map.delete(pm.transfers || %{}, event.statement_line_id)
    pending = Map.delete(pm.pending_matches || %{}, event.reconciliation_id)

    matched = Map.put(pm.matched_items || %{}, event.reconciliation_id, %{
      invoice_id: event.invoice_id,
      statement_line_id: event.statement_line_id,
      amount: event.amount,
      currency: event.currency
    })

    %__MODULE__{pm |
      org_id: event.org_id,
      invoices: invoices,
      invoice_index: i_index,
      statement_lines: lines,
      line_index: l_index,
      transfers: transfers,
      pending_matches: pending,
      matched_items: matched
    }
  end

  def apply(%__MODULE__{} = pm, %ReconciliationProposed{} = event) do
    # Remove from unmatched lists while pending
    {invoices, i_index} = case Map.pop(pm.invoices || %{}, event.invoice_id) do
      {nil, acc} -> {acc, pm.invoice_index}
      {inv, acc} -> {acc, index_remove(pm.invoice_index, inv.currency, inv.amount, event.invoice_id)}
    end

    {lines, l_index} = case Map.pop(pm.statement_lines || %{}, event.statement_line_id) do
      {nil, acc} -> {acc, pm.line_index}
      {line, acc} -> {acc, index_remove(pm.line_index, line.currency, line.amount, event.statement_line_id)}
    end

    pending = Map.put(pm.pending_matches || %{}, event.reconciliation_id, %{
      invoice_id: event.invoice_id,
      statement_line_id: event.statement_line_id,
      amount: event.amount,
      currency: event.currency
    })

    %__MODULE__{pm |
      org_id: event.org_id,
      invoices: invoices,
      invoice_index: i_index,
      statement_lines: lines,
      line_index: l_index,
      pending_matches: pending
    }
  end

  def apply(%__MODULE__{} = pm, %ReconciliationRejected{} = event) do
    case Map.pop(pm.pending_matches || %{}, event.reconciliation_id) do
      {nil, _acc} -> pm
      {%{invoice_id: i_id, statement_line_id: l_id, amount: amt, currency: cur}, pending} ->
        amt = Nexus.Schema.parse_decimal(amt)
        %__MODULE__{pm |
          invoices: Map.put(pm.invoices, i_id, %{amount: amt, currency: cur}),
          invoice_index: index_add(pm.invoice_index, cur, amt, i_id),
          statement_lines: Map.put(pm.statement_lines, l_id, %{amount: amt, currency: cur}),
          line_index: index_add(pm.line_index, cur, amt, l_id),
          pending_matches: pending
        }
    end
  end

  def apply(%__MODULE__{} = pm, %ReconciliationReversed{} = event) do
    case Map.pop(pm.matched_items || %{}, event.reconciliation_id) do
      {nil, _acc} -> pm
      {%{invoice_id: i_id, statement_line_id: l_id, amount: amt, currency: cur}, matched} ->
        amt = Nexus.Schema.parse_decimal(amt)
        %__MODULE__{pm |
          invoices: Map.put(pm.invoices, i_id, %{amount: amt, currency: cur}),
          invoice_index: index_add(pm.invoice_index, cur, amt, i_id),
          statement_lines: Map.put(pm.statement_lines, l_id, %{amount: amt, currency: cur}),
          line_index: index_add(pm.line_index, cur, amt, l_id),
          matched_items: matched
        }
    end
  end

  # --- Private Helpers ---

  defp index_add(index, currency, amount, id) do
    amount_str = amount_to_index_key(amount)

    currency_map = Map.get(index || %{}, currency, %{})
    ids = Map.get(currency_map, amount_str, [])

    if id in ids do
      index
    else
      new_ids = [id | ids]
      new_currency_map = Map.put(currency_map, amount_str, new_ids)
      Map.put(index || %{}, currency, new_currency_map)
    end
  end

  defp index_remove(index, currency, amount, id) do
    amount_str = amount_to_index_key(amount)
    index = index || %{}

    case Map.get(index, currency) do
      nil -> index
      currency_map ->
        ids = Map.get(currency_map, amount_str, [])
        new_ids = List.delete(ids, id)
        new_currency_map = Map.put(currency_map, amount_str, new_ids)
        Map.put(index, currency, new_currency_map)
    end
  end

  defp amount_to_index_key(amount) do
    # Index by absolute amount string with fixed precision for O(1) matching
    amount
    |> Decimal.abs()
    |> Decimal.round(2)
    |> Decimal.to_string()
  end
end
