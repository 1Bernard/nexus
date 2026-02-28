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
    statement_lines: %{}
  ]

  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.ERP.Events.StatementUploaded
  alias Nexus.Treasury.Commands.ReconcileTransaction
  alias Nexus.Treasury.Events.TransactionReconciled

  # Route process managers by org_id so each tenant has an isolated matching engine
  def interested?(%InvoiceIngested{org_id: org_id}), do: {:start!, org_id}
  def interested?(%StatementUploaded{org_id: org_id}), do: {:start!, org_id}
  def interested?(%TransactionReconciled{org_id: org_id}), do: {:continue!, org_id}

  # --- Handle Events (Emit Commands) ---

  def handle(%__MODULE__{} = pm, %InvoiceIngested{} = event) do
    evt_amt =
      if is_binary(event.amount),
        do: Decimal.new(event.amount),
        else: Decimal.new("#{event.amount}")

    # Try to find a matching statement line
    match =
      Enum.find(pm.statement_lines, fn {_line_id, line} ->
        line.currency == event.currency and
          Decimal.eq?(Decimal.new(line.amount), evt_amt)
      end)

    if match do
      {line_id, line} = match
      reconciliation_id = Ecto.UUID.generate()

      %ReconcileTransaction{
        org_id: event.org_id,
        reconciliation_id: reconciliation_id,
        invoice_id: event.invoice_id,
        statement_id: line.statement_id,
        statement_line_id: line_id,
        amount: event.amount,
        currency: event.currency
      }
    else
      []
    end
  end

  def handle(%__MODULE__{} = pm, %StatementUploaded{} = event) do
    # Try to match newly uploaded statement lines against open invoices
    commands =
      Enum.reduce(event.lines || [], [], fn line, acc ->
        match =
          Enum.find(pm.invoices, fn {_inv_id, inv} ->
            inv.currency == line.currency and
              Decimal.eq?(Decimal.new(inv.amount), Decimal.new(line.amount))
          end)

        id = Map.get(line, :id)

        if match && id do
          {inv_id, _inv} = match
          reconciliation_id = Ecto.UUID.generate()

          match_cmd = %ReconcileTransaction{
            org_id: event.org_id,
            reconciliation_id: reconciliation_id,
            invoice_id: inv_id,
            statement_id: event.statement_id,
            statement_line_id: id,
            amount: line.amount,
            currency: line.currency
          }

          [match_cmd | acc]
        else
          acc
        end
      end)

    Enum.reverse(commands)
  end

  def handle(%__MODULE__{}, %TransactionReconciled{}), do: []

  # --- Mutate State ---

  def apply(%__MODULE__{} = pm, %InvoiceIngested{} = event) do
    amt =
      if is_binary(event.amount),
        do: Decimal.new(event.amount),
        else: Decimal.new("#{event.amount}")

    updated_invoices =
      Map.put(pm.invoices || %{}, event.invoice_id, %{
        amount: amt,
        currency: event.currency
      })

    %__MODULE__{pm | org_id: event.org_id, invoices: updated_invoices}
  end

  def apply(%__MODULE__{} = pm, %StatementUploaded{} = event) do
    updated_lines =
      Enum.reduce(event.lines || [], pm.statement_lines || %{}, fn line, acc ->
        amt =
          if is_binary(line.amount),
            do: Decimal.new(line.amount),
            else: Decimal.new("#{line.amount}")

        id = Map.get(line, :id)

        if id && Decimal.compare(amt, Decimal.new(0)) == :gt do
          Map.put(acc, id, %{
            statement_id: event.statement_id,
            amount: amt,
            currency: line.currency
          })
        else
          acc
        end
      end)

    %__MODULE__{pm | org_id: event.org_id, statement_lines: updated_lines}
  end

  def apply(%__MODULE__{} = pm, %TransactionReconciled{} = event) do
    invoices = Map.delete(pm.invoices || %{}, event.invoice_id)
    lines = Map.delete(pm.statement_lines || %{}, event.statement_line_id)
    %__MODULE__{pm | org_id: event.org_id, invoices: invoices, statement_lines: lines}
  end
end
