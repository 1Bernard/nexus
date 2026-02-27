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
  alias Nexus.Treasury.Commands.SetTransferThreshold

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
      threshold: threshold
    }

    Nexus.App.dispatch(command)
  end
end
