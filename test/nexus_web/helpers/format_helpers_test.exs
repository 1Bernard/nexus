defmodule NexusWeb.FormatHelpersTest do
  use ExUnit.Case, async: true
  import NexusWeb.FormatHelpers

  describe "format_currency/2" do
    test "formats USD correctly" do
      assert format_currency(Decimal.new("1234.56"), currency: "USD") == "$1,234.56"
      assert format_currency(1234.56, currency: "USD") == "$1,234.56"
    end

    test "formats EUR correctly" do
      assert format_currency(Decimal.new("1234.56"), currency: "EUR") == "€1,234.56"
    end

    test "formats GBP correctly" do
      assert format_currency(Decimal.new("1234.56"), currency: "GBP") == "£1,234.56"
    end

    test "formats JPY correctly" do
      assert format_currency(Decimal.new("1234.56"), currency: "JPY") == "¥1,234.56"
    end

    test "formats CHF correctly" do
      assert format_currency(Decimal.new("1234.56"), currency: "CHF") == "₣1,234.56"
    end

    test "handles zero" do
      assert format_currency(Decimal.new("0"), currency: "USD") == "$0.00"
    end

    test "handles large numbers" do
      assert format_currency(Decimal.new("1234567.89"), currency: "USD") == "$1,234,567.89"
    end

    test "handles nil" do
      assert format_currency(nil, currency: "USD") == "—"
    end

    test "defaults to USD if currency is missing" do
      assert format_currency(Decimal.new("100"), []) == "$100.00"
    end
  end
end
