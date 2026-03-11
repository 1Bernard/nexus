defmodule Nexus.Treasury.Services.ForecastEngine do
  @moduledoc """
  Predictive engine for liquidity forecasting using Nx and Scholar.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.ERP.Projections.{Invoice, StatementLine}

  @doc """
  Generates a forecast for the given organization and currency over the specified horizon.
  """
  def calculate(org_id, currency, horizon_days \\ 30) do
    # 1. Fetch historical daily net cash flow (last 60 days)
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -60)

    data_points = fetch_daily_data(org_id, currency, start_date, end_date)

    if Enum.empty?(data_points) do
      {:error, :insufficient_data}
    else
      # 2. Prepare data for Scholar (X = days since start, Y = net amount)
      {x_list, y_list} = prepare_tensors(data_points, start_date)

      x = Nx.tensor(x_list, type: :f32) |> Nx.reshape({:auto, 1})
      y = Nx.tensor(y_list, type: :f32)

      # 3. Fit Linear Regression
      model = Scholar.Linear.LinearRegression.fit(x, y)

      # 4. Predict next 'horizon_days'
      predictions = predict_future(model, length(x_list), horizon_days)

      # 5. Merge with known invoice outflows
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

  defp prepare_tensors(data_points, start_date) do
    data_points
    |> Enum.map(fn {date, amount} ->
      {Date.diff(date, start_date), amount}
    end)
    |> Enum.unzip()
  end

  defp predict_future(model, last_day_index, horizon_days) do
    future_x =
      (last_day_index + 1)..(last_day_index + horizon_days)
      |> Enum.map(&[&1 * 1.0])
      |> Nx.tensor(type: :f32)

    predictions = Scholar.Linear.LinearRegression.predict(model, future_x)

    predictions
    |> Nx.to_flat_list()
    |> Enum.with_index(1)
    |> Enum.map(fn {val, i} ->
      %{
        date: Date.to_iso8601(Date.add(Date.utc_today(), i)),
        predicted_amount: val |> Float.round(2) |> Float.to_string()
      }
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

      # Invoices are outflows (negative impact on cash)
      # In bank statements, outflows are negative.
      # Ifpred_amt is -500 (historical trend) and inv_amt is 1000 (invoice due),
      # total outflow is -1500.
      total = pred_amt - inv_amt

      %{p | predicted_amount: Float.round(total, 2) |> Float.to_string()}
    end)
  end
end
