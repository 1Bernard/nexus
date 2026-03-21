defmodule Nexus.Treasury do
  @moduledoc """
  The Treasury context facade.

  Provides a unified API for market data, exposures, risk assessment, and trade execution.
  This facade delegates complex query orchestration to specialized query modules while
  managing command dispatch for treasury operations.
  """
  alias Nexus.Repo

  alias Nexus.Treasury.Queries.{
    MarketTickQuery,
    ExposureQuery,
    TreasuryPolicyQuery,
    PolicyAlertQuery,
    ForecastQuery,
    ReconciliationQuery,
    LiquidityPositionQuery,
    PolicyAuditLogQuery
  }

  alias Nexus.ERP.Queries.{InvoiceQuery, StatementLineQuery}

  alias Nexus.Treasury.Gateways.PriceCache

  alias Nexus.Treasury.Commands.{
    SetTransferThreshold,
    GenerateForecast,
    RequestTransfer,
    AuthorizeTransfer,
    ExecuteTransfer,
    RegisterVault,
    SyncVaultBalance
  }

  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  alias Nexus.Treasury.Services.ForecastEngine

  alias Nexus.Types

  @type risk_summary :: %{
          total_exposure: String.t(),
          at_risk: String.t(),
          max_loss: String.t()
        }

  @type exposure_heatmap :: %{
          subsidiaries: [String.t()],
          currencies: [Types.currency()],
          data: %{String.t() => %{Types.currency() => Types.money()}}
        }

  @type reconciliation_stats :: %{
          auto_matched_count: integer(),
          total_matched_count: integer(),
          match_rate: integer(),
          matching_velocity_min: integer()
        }

  @doc """
  Lists all successful reconciliations for an organization.
  """
  @spec list_reconciliations(Types.org_id()) :: [Reconciliation.t()]
  def list_reconciliations(org_id) do
    ReconciliationQuery.list_query(org_id)
    |> Repo.all()
  end

  @doc """
  Lists all invoices that are currently unmatched.
  """
  @spec list_unmatched_invoices(Types.org_id()) :: [Invoice.t()]
  def list_unmatched_invoices(org_id) do
    InvoiceQuery.base(org_id)
    |> InvoiceQuery.with_tenant()
    |> InvoiceQuery.with_status("ingested")
    |> InvoiceQuery.newest_first()
    |> Repo.all()
  end

  @doc """
  Lists all statement lines that are currently unmatched.
  """
  @spec list_unmatched_statement_lines(Types.org_id()) :: [StatementLine.t()]
  def list_unmatched_statement_lines(org_id) do
    StatementLineQuery.base(org_id)
    |> StatementLineQuery.with_tenant()
    |> StatementLineQuery.with_status("unmatched")
    |> StatementLineQuery.newest_first()
    |> Repo.all()
  end

  @doc """
  Lists recent policy alerts for an organization.
  """
  @spec list_policy_alerts(Types.org_id() | :all, integer()) :: [
          Nexus.Treasury.Projections.PolicyAlert.t()
        ]
  def list_policy_alerts(org_id, limit \\ 5) do
    import Ecto.Query

    PolicyAlertQuery.base(org_id)
    |> join(:left, [a], t in Nexus.Organization.Projections.Tenant, on: a.org_id == t.org_id)
    |> select([a, t], %{a | org_name: t.name})
    |> PolicyAlertQuery.recent(limit)
    |> Repo.all()
  end

  @doc """
  Lists policy audit logs for an organization.
  """
  @spec list_policy_audit_logs(Types.org_id()) :: [Nexus.Treasury.Projections.PolicyAuditLog.t()]
  def list_policy_audit_logs(org_id) do
    PolicyAuditLogQuery.list_for_org(org_id)
    |> Repo.all()
  end

  @doc """
  Fetches the treasury policy for an organization.
  """
  @spec get_policy_mode(Types.org_id()) :: Nexus.Treasury.Projections.TreasuryPolicy.t() | nil
  def get_policy_mode(:all), do: nil

  def get_policy_mode(org_id) do
    TreasuryPolicyQuery.base(org_id)
    |> Repo.one()
  end

  @doc """
  Fetches the latest forecast for a currency.
  """
  @spec get_latest_forecast(Types.org_id() | :all, Types.currency()) ::
          Nexus.Treasury.Projections.ForecastSnapshot.t() | nil
  def get_latest_forecast(org_id, currency) do
    require Ecto.Query

    ForecastQuery.base(org_id)
    |> ForecastQuery.for_currency(currency)
    |> ForecastQuery.newest_first()
    |> Ecto.Query.limit(1)
    |> Repo.one()
  end

  @doc """
  Lists historical daily net cash flow for an organization and currency.
  """
  @spec list_historical_cash_flow(Types.org_id(), Types.currency(), integer()) :: [map()]
  def list_historical_cash_flow(org_id, currency, days \\ 60) do
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -days)

    StatementLineQuery.historical_cash_flow_query(
      org_id,
      currency,
      Date.to_string(start_date),
      Date.to_string(end_date)
    )
    |> Repo.all()
    |> Enum.map(fn %{date: date_str, amount: total_amount} ->
      %{
        date: date_str,
        amount: Decimal.round(total_amount, 2)
      }
    end)
  end

  @doc """
  Returns a CSV-formatted string of the latest forecast data points.
  """
  @spec list_forecast_csv(Types.org_id() | :all, Types.currency()) :: String.t()
  def list_forecast_csv(org_id, currency) do
    case get_latest_forecast(org_id, currency) do
      nil ->
        "Date,Predicted Amount\n"

      forecast ->
        header = "Date,Predicted Amount (#{currency})\n"

        body =
          forecast.data_points
          |> Enum.map(fn point -> "#{point["date"]},#{point["predicted_amount"]}" end)
          |> Enum.join("\n")

        header <> body
    end
  end

  @doc """
  Triggers a liquidity forecast calculation and dispatches the command.
  """
  @spec generate_forecast(Types.org_id(), Types.currency(), integer(), keyword()) ::
          :ok | {:error, any()}
  def generate_forecast(org_id, currency, horizon_days \\ 30, opts \\ []) do
    case ForecastEngine.calculate(org_id, currency, horizon_days) do
      {:ok, predictions} ->
        idempotency_key = Keyword.get(opts, :idempotency_key) || Nexus.Schema.generate_uuidv7()

        command = %GenerateForecast{
          org_id: org_id,
          currency: currency,
          horizon_days: horizon_days,
          predictions: predictions,
          generated_at: Nexus.Schema.utc_now(),
          idempotency_key: idempotency_key
        }

        dispatch_opts = Keyword.take(opts, [:consistency, :timeout])
        dispatch_opts = Keyword.put_new(dispatch_opts, :consistency, :strong)

        Nexus.App.dispatch(command, dispatch_opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a risk summary for an organization, including Net Exposure
  and Value at Risk (VAR). Normalizes all currency exposures into the
  org's reporting currency (default USD).
  """
  @spec get_risk_summary(Types.org_id()) :: risk_summary()
  def get_risk_summary(org_id) do
    # 1. Fetch reporting currency
    policy = get_treasury_policy(org_id)
    reporting_currency = (policy && policy.reporting_currency) || "USD"

    # 2. Fetch all exposures for the org (Gross Invoice Volume)
    gross_invoice_exposures =
      ExposureQuery.base(org_id)
      |> Repo.all()

    liquidity_positions =
      LiquidityPositionQuery.base(org_id)
      |> Repo.all()

    # 4. Consolidate into Net Exposure in reporting currency
    # Map liquidity by currency for easy lookup
    liquidity_map =
      Enum.reduce(liquidity_positions, %{}, fn position, acc ->
        existing_amount = Map.get(acc, position.currency, Decimal.new(0))
        Map.put(acc, position.currency, Decimal.add(existing_amount, position.amount))
      end)

    # Collect all unique currencies from both exposures and liquidity
    all_currencies =
      (Enum.map(gross_invoice_exposures, & &1.currency) ++ Map.keys(liquidity_map))
      |> Enum.uniq()

    total_net_exposure =
      Enum.reduce(all_currencies, Decimal.new(0), fn curr, acc ->
        # We only care about foreign currency risk
        if curr == reporting_currency do
          acc
        else
          gross =
            Enum.find(gross_invoice_exposures, &(&1.currency == curr))
            |> case do
              nil -> Decimal.new(0)
              exp -> exp.exposure_amount
            end

          liquid = Map.get(liquidity_map, curr, Decimal.new(0))
          # Net Exposure for a currency is Gross Exposure - Liquid balances
          # Example: 1M EUR Liabilities - 400k EUR Cash = 600k Net Exposure
          net_in_curr = Decimal.sub(gross, liquid)

          converted = convert_to_reporting(net_in_curr, curr, reporting_currency)
          Decimal.add(acc, Decimal.abs(converted))
        end
      end)

    # 5. Calculate VAR and Max Loss (VAR is 8% of total net exposure)
    value_at_risk = Decimal.mult(Decimal.abs(total_net_exposure), Decimal.new("0.08"))

    %{
      total_exposure: format_currency(total_net_exposure, reporting_currency),
      at_risk: format_currency(value_at_risk, reporting_currency),
      max_loss:
        format_currency(Decimal.mult(value_at_risk, Decimal.new("0.25")), reporting_currency)
    }
  end

  defp convert_to_reporting(amount, currency, reporting_currency) do
    if currency == reporting_currency do
      amount
    else
      # Try to find a direct or inverse rate
      pair = "#{currency}/#{reporting_currency}"
      inv_pair = "#{reporting_currency}/#{currency}"

      case PriceCache.get_price(pair) do
        {:ok, price} ->
          Decimal.mult(amount, Decimal.new(price))

        _ ->
          case PriceCache.get_price(inv_pair) do
            {:ok, inv_price} ->
              # amount / inv_price = amount * (1 / inv_price)
              Decimal.div(amount, Decimal.new(inv_price))

            _ ->
              # Fallback if no rate found (return 1:1 for safety in demo)
              amount
          end
      end
    end
  end

  defp format_currency(amount, currency) do
    symbol =
      case currency do
        "USD" -> "$"
        "EUR" -> "€"
        "GBP" -> "£"
        _ -> "#{currency} "
      end

    cond do
      Decimal.compare(amount, Decimal.new(1_000_000)) != :lt ->
        "#{symbol}#{Decimal.div(amount, 1_000_000) |> Decimal.round(1)}M"

      Decimal.compare(amount, Decimal.new(1_000)) != :lt ->
        "#{symbol}#{Decimal.div(amount, 1_000) |> Decimal.round(0)}K"

      true ->
        "#{symbol}#{Decimal.round(amount, 0)}"
    end
  end

  @doc """
  Lists active currency pairs with their latest prices and changes.
  """
  @spec list_active_currencies() :: [map()]
  def list_active_currencies do
    [
      {"EUR/USD", "+0.12%"},
      {"GBP/USD", "-0.05%"},
      {"USD/JPY", "+0.45%"}
    ]
    |> Enum.map(fn {currency_pair, default_change} ->
      price =
        case PriceCache.get_price(currency_pair) do
          {:ok, price} -> price
          _ -> "1.0000"
        end

      %{name: currency_pair, price: to_string(price), change: default_change}
    end)
  end

  @doc """
  Lists exposure snapshots for the heatmap view.
  Returns data structured by subsidiary and currency.
  """
  @spec list_exposure_heatmap(Types.org_id()) :: exposure_heatmap()
  def list_exposure_heatmap(org_id) do
    # Fetch all snapshots for the org
    snapshots =
      ExposureQuery.base(org_id)
      |> Repo.all()

    # Dynamic extraction of active subsidiaries and currencies from existing snapshots
    # This allows new branches and currencies to appear automatically as invoices are ingested.
    subsidiaries =
      snapshots
      |> Enum.map(& &1.subsidiary)
      |> Enum.uniq()
      |> Enum.sort()

    currencies =
      snapshots
      |> Enum.map(& &1.currency)
      |> Enum.uniq()
      |> Enum.sort()

    # Fallback to defaults to ensure a polished UI experience for new organizations/demo
    subsidiaries =
      if Enum.empty?(subsidiaries),
        do: ["Munich HQ", "Tokyo Branch", "Corporate Operations"],
        else: subsidiaries

    currencies =
      if Enum.empty?(currencies),
        do: ["EUR", "USD", "GBP", "JPY", "CHF"],
        else: currencies

    # Map into a nested structure: %{subsidiary => %{currency => amount}}
    snapshots_map =
      Enum.reduce(snapshots, %{}, fn snapshot, acc ->
        path = [Access.key(snapshot.subsidiary, %{}), snapshot.currency]
        existing = get_in(acc, path) || Decimal.new(0)
        put_in(acc, path, Decimal.add(existing, snapshot.exposure_amount))
      end)

    %{
      subsidiaries: subsidiaries,
      currencies: currencies,
      data: snapshots_map
    }
  end

  @doc """
  Lists recent OHLC buckets for a pair.
  Buckets individual ticks into time-based intervals (default 5m).
  """
  @spec list_recent_ohlc(String.t(), integer(), integer()) :: [list()]
  def list_recent_ohlc(pair, bucket_minutes \\ 5, limit \\ 40) do
    MarketTickQuery.base()
    |> MarketTickQuery.for_pair(pair)
    |> MarketTickQuery.newest_first()
    |> MarketTickQuery.recent(1000)
    |> Repo.all()
    |> bucket_ticks_to_ohlc(bucket_minutes)
    |> Enum.sort_by(fn [time_str | _] -> time_str end)
    |> Enum.take(-limit)
  end

  defp bucket_ticks_to_ohlc(ticks, bucket_minutes) do
    ticks
    |> Enum.group_by(&round_to_bucket(&1.tick_time, bucket_minutes))
    |> Enum.map(fn {bucket_time, bucket_ticks} ->
      calculate_ohlc_row(bucket_time, bucket_ticks)
    end)
  end

  defp round_to_bucket(time, minutes) do
    unix = DateTime.to_unix(time)
    seconds = minutes * 60
    rounded_unix = div(unix, seconds) * seconds
    DateTime.from_unix!(rounded_unix)
  end

  defp calculate_ohlc_row(bucket_time, ticks) do
    sorted = Enum.sort_by(ticks, & &1.tick_time)
    prices = Enum.map(ticks, & &1.price)

    [
      DateTime.to_iso8601(bucket_time),
      List.first(sorted).price,
      List.last(sorted).price,
      Enum.min(prices),
      Enum.max(prices)
    ]
  end

  @doc """
  Fetches the treasury policy for an organization.
  """
  @spec get_treasury_policy(Types.org_id()) :: Nexus.Treasury.Projections.TreasuryPolicy.t() | nil
  def get_treasury_policy(:all), do: nil

  def get_treasury_policy(org_id) do
    TreasuryPolicyQuery.base(org_id)
    |> Repo.one()
  end

  @doc """
  Updates the transfer threshold for an organization.
  """
  @spec update_transfer_threshold(Types.org_id(), String.t() | number()) :: :ok | {:error, any()}
  def update_transfer_threshold(org_id, threshold) do
    command = %SetTransferThreshold{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      threshold: threshold,
      set_at: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Manually reconciles an invoice with a statement line.
  """
  @spec reconcile_manually(
          Types.org_id(),
          Types.binary_id(),
          Types.binary_id(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) :: :ok | {:error, any()}
  def reconcile_manually(
        org_id,
        invoice_id,
        statement_line_id,
        variance \\ nil,
        reason \\ nil,
        actor_email \\ nil
      ) do
    # Fetch details to populate the command
    invoice = Repo.get_by!(Invoice, id: invoice_id, org_id: org_id)
    line = Repo.get_by!(StatementLine, id: statement_line_id, org_id: org_id)

    needs_approval =
      variance &&
        Decimal.compare(Decimal.abs(Decimal.new(variance)), Decimal.new("500.00")) == :gt

    command =
      if needs_approval do
        %Nexus.Treasury.Commands.ProposeReconciliation{
          reconciliation_id: Nexus.Schema.generate_uuidv7(),
          org_id: org_id,
          invoice_id: invoice.id,
          statement_id: line.statement_id,
          statement_line_id: line.id,
          amount: line.amount,
          variance: variance,
          variance_reason: reason,
          actor_email: actor_email,
          currency: line.currency,
          timestamp: Nexus.Schema.utc_now()
        }
      else
        %Nexus.Treasury.Commands.ReconcileTransaction{
          reconciliation_id: Nexus.Schema.generate_uuidv7(),
          org_id: org_id,
          invoice_id: invoice.id,
          statement_id: line.statement_id,
          statement_line_id: line.id,
          amount: line.amount,
          variance: variance,
          variance_reason: reason,
          actor_email: actor_email,
          currency: line.currency,
          timestamp: Nexus.Schema.utc_now()
        }
      end

    Nexus.App.dispatch(command)
  end

  @doc """
  Approves a pending reconciliation.
  """
  @spec approve_reconciliation(Types.org_id(), Types.binary_id(), String.t()) ::
          :ok | {:error, any()}
  def approve_reconciliation(org_id, reconciliation_id, approver_email) do
    command = %Nexus.Treasury.Commands.ApproveReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      approver_email: approver_email,
      timestamp: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Rejects a pending reconciliation.
  """
  @spec reject_reconciliation(Types.org_id(), Types.binary_id(), String.t()) ::
          :ok | {:error, any()}
  def reject_reconciliation(org_id, reconciliation_id, rejector_email) do
    command = %Nexus.Treasury.Commands.RejectReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      rejector_email: rejector_email,
      timestamp: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Reverses a previously matched reconciliation.
  """
  @spec reverse_reconciliation(Types.org_id(), Types.binary_id(), String.t() | nil) ::
          :ok | {:error, any()}
  def reverse_reconciliation(org_id, reconciliation_id, actor_email \\ nil) do
    command = %Nexus.Treasury.Commands.ReverseReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      actor_email: actor_email,
      timestamp: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Lists all liquidity positions for an organization.
  """
  @spec list_liquidity_positions(Types.org_id()) :: [
          Nexus.Treasury.Projections.LiquidityPosition.t()
        ]
  def list_liquidity_positions(org_id) do
    LiquidityPositionQuery.for_org_query(org_id)
    |> Repo.all()
  end

  @doc """
  Returns reconciliation statistics for an organization.
  """
  @spec get_reconciliation_stats(Types.org_id()) :: reconciliation_stats()
  def get_reconciliation_stats(org_id) do
    reconciliations =
      ReconciliationQuery.stats_query(org_id)
      |> Repo.all()

    auto_matched =
      Enum.count(
        reconciliations,
        &(&1.status == :matched and &1.actor_email == "system@nexus.ai")
      )

    total_matched = Enum.count(reconciliations, &(&1.status == :matched))

    # Calculate average matching velocity (time from statement upload to match)
    # For demo, we use the difference between created_at and matched_at
    velocity =
      if total_matched > 0 do
        matching_differences =
          Enum.map(reconciliations, fn reconciliation ->
            DateTime.diff(reconciliation.created_at, reconciliation.matched_at, :minute) |> abs()
          end)

        (Enum.sum(matching_differences) / Enum.count(matching_differences)) |> round()
      else
        0
      end

    %{
      auto_matched_count: auto_matched,
      total_matched_count: total_matched,
      match_rate: if(total_matched > 0, do: round(auto_matched / total_matched * 100), else: 0),
      matching_velocity_min: velocity
    }
  end

  @doc """
  Initiates a fund transfer request.
  """
  @spec request_transfer(map()) :: :ok | {:error, any()}
  def request_transfer(attrs) do
    command = %RequestTransfer{
      transfer_id: attrs.transfer_id,
      org_id: attrs.org_id,
      user_id: attrs.user_id,
      from_currency: attrs.from_currency,
      to_currency: attrs.to_currency,
      amount: attrs.amount,
      threshold: attrs.threshold,
      bulk_payment_id: Map.get(attrs, :bulk_payment_id),
      requested_at: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Authorizes a pending transfer.
  """
  @spec authorize_transfer(Types.org_id(), Types.binary_id(), String.t() | nil) ::
          :ok | {:error, any()}
  def authorize_transfer(org_id, transfer_id, actor_email \\ nil) do
    command = %AuthorizeTransfer{
      transfer_id: transfer_id,
      org_id: org_id,
      actor_email: actor_email,
      authorized_at: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Finalizes and executes an authorized transfer.
  """
  @spec execute_transfer(Types.org_id(), Types.binary_id()) :: :ok | {:error, any()}
  def execute_transfer(org_id, transfer_id) do
    command = %ExecuteTransfer{
      transfer_id: transfer_id,
      org_id: org_id,
      executed_at: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Registers a new physical bank account (Vault).
  """
  @spec register_vault(map(), keyword()) :: :ok | {:error, any()}
  def register_vault(attrs, opts \\ []) do
    command = %RegisterVault{
      vault_id: Nexus.Schema.generate_uuidv7(),
      org_id: attrs.org_id,
      name: attrs.name,
      bank_name: attrs.bank_name,
      account_number: Map.get(attrs, :account_number),
      iban: Map.get(attrs, :iban),
      currency: attrs.currency,
      provider: attrs.provider,
      registered_at: Nexus.Schema.utc_now(),
      daily_withdrawal_limit:
        Nexus.Schema.parse_decimal(Map.get(attrs, :daily_withdrawal_limit, 0)),
      requires_multi_sig: Map.get(attrs, :requires_multi_sig, false)
    }

    Nexus.App.dispatch(command, opts)
  end

  @doc """
  Syncs the latest balance for a vault.
  """
  @spec sync_vault_balance(map(), keyword()) :: :ok | {:error, any()}
  def sync_vault_balance(attrs, opts \\ []) do
    command = %SyncVaultBalance{
      vault_id: attrs.vault_id,
      org_id: attrs.org_id,
      amount: attrs.amount,
      currency: attrs.currency,
      synced_at: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command, opts)
  end
end
