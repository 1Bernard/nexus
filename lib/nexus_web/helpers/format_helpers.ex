defmodule NexusWeb.FormatHelpers do
  @moduledoc """
  High-fidelity formatting utilities for the Nexus web layer.
  Ensures consistent, institution-grade display of financial data.
  """

  @doc """
  Formats a decimal or number as a currency string.
  Supports USD, EUR, GBP, JPY, and CHF with appropriate symbols and precision.

  ## Examples

      iex> format_currency(Decimal.new("1234.56"), currency: "USD")
      "$1,234.56"

      iex> format_currency(Decimal.new("0"), currency: "EUR")
      "€0.00"
  """
  def format_currency(nil, _opts), do: "—"

  def format_currency(amount, opts) do
    currency = Keyword.get(opts, :currency, "USD")
    symbol = get_symbol(currency)
    decimal_amount = Decimal.new(to_string(amount))

    formatted =
      decimal_amount
      |> Decimal.round(2)
      |> Decimal.to_string(:normal)
      |> add_commas()

    "#{symbol}#{formatted}"
  end

  defp get_symbol("USD"), do: "$"
  defp get_symbol("EUR"), do: "€"
  defp get_symbol("GBP"), do: "£"
  defp get_symbol("JPY"), do: "¥"
  defp get_symbol("CHF"), do: "₣"
  defp get_symbol(_), do: ""

  @doc """
  Formats a datetime as a relative time string (e.g., "5m ago").
  """
  def format_relative_time(nil), do: "Never"

  def format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp add_commas(string) do
    [digits, decimals] =
      case String.split(string, ".") do
        [d, dec] -> [d, dec]
        [d] -> [d, "00"]
      end

    # Ensure decimals are always 2 digits
    decimals = String.pad_trailing(decimals, 2, "0")

    # Add commas to digits
    formatted_digits =
      digits
      |> String.to_charlist()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    "#{formatted_digits}.#{decimals}"
  end
end
