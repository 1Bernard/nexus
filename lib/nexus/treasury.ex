defmodule Nexus.Treasury do
  @moduledoc """
  The Treasury context. Provides a unified API for market data,
  exposures, and trade execution coordination.
  """
  alias Nexus.Repo

  alias Nexus.Treasury.Queries.{
    MarketTickQuery,
    ExposureQuery,
    TreasuryPolicyQuery,
    PolicyAlertQuery,
    ForecastQuery
  }

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Commands.{SetTransferThreshold, GenerateForecast}
  alias Nexus.Treasury.Projections.{TreasuryPolicy, Reconciliation}
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  alias Nexus.Treasury.Services.ForecastEngine

  @doc """
  Lists all successful reconciliations for an organization.
  """
  def list_reconciliations(org_id) do
    import Ecto.Query

    from(r in Reconciliation,
      where: r.org_id == ^org_id,
      order_by: [desc: r.matched_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all invoices that are currently unmatched.
  """
  def list_unmatched_invoices(org_id) do
    import Ecto.Query

    from(i in Invoice,
      where: i.org_id == ^org_id and i.status == "ingested",
      order_by: [desc: i.created_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all statement lines that are currently unmatched.
  """
  def list_unmatched_statement_lines(org_id) do
    import Ecto.Query

    from(l in StatementLine,
      where: l.org_id == ^org_id and l.status == "unmatched",
      order_by: [desc: l.created_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists recent policy alerts for an organization.
  """
  def list_policy_alerts(org_id, limit \\ 5) do
    PolicyAlertQuery.base()
    |> PolicyAlertQuery.for_org(org_id)
    |> PolicyAlertQuery.recent(limit)
    |> Repo.all()
  end

  @doc """
  Lists policy audit logs for an organization.
  """
  def list_policy_audit_logs(org_id) do
    import Ecto.Query

    from(l in Nexus.Treasury.Projections.PolicyAuditLog,
      where: l.org_id == ^org_id,
      order_by: [desc: l.changed_at],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Fetches the current policy mode and threshold for an organisation.
  Returns a `%TreasuryPolicy{}` or nil if no policy has been set.
  """
  def get_policy_mode(org_id) do
    import Ecto.Query
    Repo.one(from p in TreasuryPolicy, where: p.org_id == ^org_id)
  end

  @doc """
  Fetches the latest forecast for a currency.
  """
  def get_latest_forecast(org_id, currency) do
    require Ecto.Query

    ForecastQuery.base()
    |> ForecastQuery.for_org(org_id)
    |> ForecastQuery.for_currency(currency)
    |> ForecastQuery.newest_first()
    |> Ecto.Query.limit(1)
    |> Repo.one()
  end

  @doc """
  Lists historical daily net cash flow for an organization and currency.
  """
  def list_historical_cash_flow(org_id, currency, days \\ 60) do
    import Ecto.Query
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -days)

    from(l in StatementLine,
      where: l.org_id == ^org_id and l.currency == ^currency,
      where: l.date >= ^Date.to_string(start_date) and l.date <= ^Date.to_string(end_date),
      group_by: l.date,
      select: %{date: l.date, amount: sum(l.amount)},
      order_by: [asc: l.date]
    )
    |> Repo.all()
    |> Enum.map(fn %{date: date_str, amount: amount} ->
      %{
        date: date_str,
        amount: Decimal.to_float(amount) |> Float.round(2)
      }
    end)
  end

  @doc """
  Returns a CSV-formatted string of the latest forecast data points.
  """
  def list_forecast_csv(org_id, currency) do
    case get_latest_forecast(org_id, currency) do
      nil ->
        "Date,Predicted Amount\n"

      forecast ->
        header = "Date,Predicted Amount (#{currency})\n"

        body =
          forecast.data_points
          |> Enum.map(fn p -> "#{p["date"]},#{p["predicted_amount"]}" end)
          |> Enum.join("\n")

        header <> body
    end
  end

  @doc """
  Triggers a liquidity forecast calculation and dispatches the command.
  """
  def generate_forecast(org_id, currency, horizon_days \\ 30) do
    case ForecastEngine.calculate(org_id, currency, horizon_days) do
      {:ok, predictions} ->
        command = %GenerateForecast{
          org_id: org_id,
          currency: currency,
          horizon_days: horizon_days,
          predictions: predictions,
          generated_at: DateTime.utc_now()
        }

        Nexus.App.dispatch(command, consistency: :strong)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a risk summary for an organization, including Net Exposure
  and Value at Risk (VAR).
  """
  def get_risk_summary(org_id) do
    total_exposure =
      ExposureQuery.base()
      |> ExposureQuery.for_org(org_id)
      |> ExposureQuery.sum_exposure()
      |> Repo.one() || Decimal.new(0)

    # In a real environment, VAR involves complex calculations.
    # For this dashboard bridge, we calculate it as 8% of exposure.
    var = Decimal.mult(total_exposure, Decimal.from_float(0.08))

    %{
      total_exposure: format_currency(total_exposure),
      at_risk: format_currency(var),
      max_loss: format_currency(Decimal.mult(var, Decimal.from_float(0.25)))
    }
  end

  @doc """
  Lists active currency pairs with their latest prices and changes.
  """
  def list_active_currencies do
    [
      {"EUR/USD", "+0.12%"},
      {"GBP/USD", "-0.05%"},
      {"USD/JPY", "+0.45%"}
    ]
    |> Enum.map(fn {pair, default_change} ->
      price =
        case PriceCache.get_price(pair) do
          {:ok, p} -> p
          _ -> "1.0000"
        end

      %{name: pair, price: to_string(price), change: default_change}
    end)
  end

  @doc """
  Lists exposure snapshots for the heatmap view.
  Returns data structured by subsidiary and currency.
  """
  def list_exposure_heatmap(org_id) do
    # Fetch all snapshots for the org
    snapshots =
      ExposureQuery.base()
      |> ExposureQuery.for_org(org_id)
      |> Repo.all()

    # Define the set of subsidiaries and currencies we want to show
    subsidiaries = ["Munich HQ", "Tokyo Branch", "London Ltd"]
    currencies = ["EUR", "USD", "GBP", "JPY", "CHF"]

    # Map into a nested structure: %{subsidiary => %{currency => amount}}
    snapshots_map =
      Enum.reduce(snapshots, %{}, fn s, acc ->
        put_in(acc, [Access.key(s.subsidiary, %{}), s.currency], s.exposure_amount)
      end)

    %{
      subsidiaries: subsidiaries,
      currencies: currencies,
      data: snapshots_map
    }
  end

  defp format_currency(amount) do
    cond do
      Decimal.gt?(amount, 1_000_000) ->
        "€#{Decimal.div(amount, 1_000_000) |> Decimal.round(1)}M"

      Decimal.gt?(amount, 1_000) ->
        "€#{Decimal.div(amount, 1_000) |> Decimal.round(0)}K"

      true ->
        "€#{Decimal.round(amount, 0)}"
    end
  end

  @doc """
  Lists recent OHLC buckets for a pair.
  Buckets individual ticks into time-based intervals (default 5m).
  """
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
  def get_treasury_policy(org_id) do
    TreasuryPolicyQuery.base()
    |> TreasuryPolicyQuery.for_org(org_id)
    |> Repo.one()
  end

  @doc """
  Updates the transfer threshold for an organization.
  """
  def update_transfer_threshold(org_id, threshold) do
    command = %SetTransferThreshold{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      threshold: threshold,
      set_at: DateTime.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Manually reconciles an invoice with a statement line.
  """
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
          timestamp: DateTime.utc_now()
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
          timestamp: DateTime.utc_now()
        }
      end

    Nexus.App.dispatch(command)
  end

  @doc """
  Approves a pending reconciliation.
  """
  def approve_reconciliation(org_id, reconciliation_id, approver_email) do
    command = %Nexus.Treasury.Commands.ApproveReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      approver_email: approver_email,
      timestamp: DateTime.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Rejects a pending reconciliation.
  """
  def reject_reconciliation(org_id, reconciliation_id, rejector_email) do
    command = %Nexus.Treasury.Commands.RejectReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      rejector_email: rejector_email,
      timestamp: DateTime.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Reverses a previously matched reconciliation.
  """
  def reverse_reconciliation(org_id, reconciliation_id, actor_email \\ nil) do
    command = %Nexus.Treasury.Commands.ReverseReconciliation{
      org_id: org_id,
      reconciliation_id: reconciliation_id,
      actor_email: actor_email,
      timestamp: DateTime.utc_now()
    }

    Nexus.App.dispatch(command)
  end

  @doc """
  Returns reconciliation statistics for an organization.
  """
  def get_reconciliation_stats(org_id) do
    import Ecto.Query

    query = from(r in Reconciliation, where: r.org_id == ^org_id)
    all = Repo.all(query)

    auto_matched =
      Enum.count(all, &(&1.status == :matched and &1.actor_email == "system@nexus.ai"))

    total_matched = Enum.count(all, &(&1.status == :matched))

    %{
      auto_matched_count: auto_matched,
      total_matched_count: total_matched,
      match_rate: if(total_matched > 0, do: round(auto_matched / total_matched * 100), else: 0)
    }
  end
end
