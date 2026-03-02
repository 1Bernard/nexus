defmodule Nexus.Treasury.Services.ForecastEngine do
  @moduledoc """
  Predictive engine for liquidity forecasting using Nx and Scholar.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.ERP.Projections.StatementLine

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

      {:ok, predictions}
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
end
