defmodule Nexus.Treasury.Services.ForecastMath do
  @moduledoc """
  Pure mathematical logic for liquidity forecasting using Nx and Scholar.
  Decoupled from Data I/O (Rule 5).
  """

  @doc """
  Prepares and fits a linear regression model to the given data points.
  All tensor variables are suffixed with _tensor (Rule 13).
  """
  @spec generate_predictions(list(), Date.t(), integer()) :: list(map())
  def generate_predictions(data_points, start_date, horizon_days) do
    {x_list, y_list} = prepare_tensors(data_points, start_date)

    x_tensor = Nx.tensor(x_list, type: :f32) |> Nx.reshape({:auto, 1})
    y_tensor = Nx.tensor(y_list, type: :f32)

    # Fit Linear Regression
    model = Scholar.Linear.LinearRegression.fit(x_tensor, y_tensor)

    # Predict next 'horizon_days'
    predict_future(model, length(x_list), horizon_days)
  end

  defp prepare_tensors(data_points, start_date) do
    data_points
    |> Enum.map(fn {date, amount} ->
      {Date.diff(date, start_date), amount}
    end)
    |> Enum.unzip()
  end

  defp predict_future(model, last_day_index, horizon_days) do
    future_x_tensor =
      (last_day_index + 1)..(last_day_index + horizon_days)
      |> Enum.map(&[&1 * 1.0])
      |> Nx.tensor(type: :f32)

    predictions_tensor = Scholar.Linear.LinearRegression.predict(model, future_x_tensor)

    predictions_tensor
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
