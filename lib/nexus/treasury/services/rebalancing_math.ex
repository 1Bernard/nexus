defmodule Nexus.Treasury.Services.RebalancingMath do
  @moduledoc """
  Pure functional logic for portfolio rebalancing.
  Isolates predictive math from Data I/O as per Rule 5.
  """

  @doc """
  Calculates suggested trades based on drift from targets.
  """
  @spec calculate_trades(list(), map(), Decimal.t()) :: [map()]
  def calculate_trades(positions, target_map, rebalance_threshold) do
    reporting_currency = "USD"

    total_value = Enum.reduce(positions, Decimal.new(0), fn pos, acc ->
      converted = Nexus.Treasury.convert_to_reporting(pos.amount, pos.currency, reporting_currency)
      Decimal.add(acc, converted)
    end)

    Enum.flat_map(target_map, fn {currency, target_weight} ->
      current_pos = Enum.find(positions, %{amount: Decimal.new(0)}, &(&1.currency == currency))
      current_in_reporting = Nexus.Treasury.convert_to_reporting(current_pos.amount, currency, reporting_currency)
      current_weight = calculate_weight(current_in_reporting, total_value)

      drift = Decimal.sub(current_weight, Decimal.from_float(target_weight))

      if Decimal.abs(drift) > rebalance_threshold do
        amount_to_move = Decimal.mult(drift, total_value)
        [%{currency: currency, drift: drift, amount: amount_to_move}]
      else
        []
      end
    end)
  end

  defp calculate_weight(amount, total) do
    if Decimal.equal?(total, Decimal.new(0)) do
      Decimal.new(0)
    else
      Decimal.div(amount, total)
    end
  end
end
