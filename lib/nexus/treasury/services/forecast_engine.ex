defmodule Nexus.Treasury.Services.ForecastEngine do
  @moduledoc """
  Predictive engine for liquidity forecasting.
  Coordinates Data I/O and delegates math to ForecastMath (Rule 5).
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  alias Nexus.Treasury.Services.ForecastMath
  alias Nexus.Types

  @doc """
  Generates a forecast for the given organization and currency.
  Uses deep type alignment for org_id (Rule 14).
  """
  @spec calculate(Types.org_id(), Types.currency(), integer()) ::
          {:ok, list(map())} | {:error, atom()}
  def calculate(org_id, currency, horizon_days \\ 30) do
    # 1. Fetch historical daily net cash flow (last 60 days)
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -60)

    data_points = fetch_daily_data(org_id, currency, start_date, end_date)

    if Enum.empty?(data_points) do
      {:error, :insufficient_data}
    else
      # 2. Delegate math to PURE module (Rule 5)
      predictions = ForecastMath.generate_predictions(data_points, start_date, horizon_days)

      # 3. Merge with known invoice outflows
      invoices = fetch_upcoming_invoices(org_id, currency, end_date, horizon_days)
      merged_predictions = merge_invoices_into_predictions(predictions, invoices)

      {:ok, merged_predictions}
    end
  end

  defp fetch_daily_data(org_id, currency, start_date, end_date) do
    from(l in StatementLine,
      where: l.org_id == ^org_id and l.currency == ^currency,
      where: l.date >= ^Date.to_string(start_date) and l.date <= ^Date.to_string(end_date),
      group_by: l.date,
      select: {l.date, sum(l.amount)},
      order_by: [asc: l.date]
    )
    |> Repo.all()
    |> Enum.map(fn {date_str, amount} ->
      {Date.from_iso8601!(date_str), Decimal.to_float(amount)}
    end)
  end

  defp fetch_upcoming_invoices(org_id, currency, start_date, horizon_days) do
    end_date = Date.add(start_date, horizon_days)

    from(i in Invoice,
      where: i.org_id == ^org_id and i.currency == ^currency,
      where: i.status != "matched",
      where:
        fragment("?::date", i.due_date) > ^start_date and
          fragment("?::date", i.due_date) <= ^end_date,
      group_by: fragment("?::date", i.due_date),
      select: {fragment("?::date", i.due_date), sum(fragment("CAST(? AS decimal)", i.amount))}
    )
    |> Repo.all()
    |> Enum.map(fn {date, sum} -> {date, Decimal.to_float(sum)} end)
    |> Map.new()
  end

  defp merge_invoices_into_predictions(predictions, invoices) do
    Enum.map(predictions, fn p ->
      date = Date.from_iso8601!(p.date)
      pred_amt = String.to_float(p.predicted_amount)
      inv_amt = Map.get(invoices, date, 0.0)

      total = pred_amt - inv_amt

      %{p | predicted_amount: Float.round(total, 2) |> Float.to_string()}
    end)
  end
end
