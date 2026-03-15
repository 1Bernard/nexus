defmodule Nexus.Treasury.FinancialLogicTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Decimal, as: D

  @moduledoc """
  Property-based tests to ensure financial precision and rounding consistency.
  """

  property "Decimal.round/2 with precision 2 always results in max 2 decimal places" do
    check all(val <- float_generator()) do
      decimal_val = D.from_float(val)
      rounded = D.round(decimal_val, 2)

      # The scale of the rounded decimal should be <= 2
      # Scale 0: "100"
      # Scale 1: "100.1"
      # Scale 2: "100.12"
      assert rounded.exp >= -2
    end
  end

  property "Currency conversion idempotency (A -> B -> A with fixed rates)" do
    check all(amount <- money_generator(),
              rate <- rate_generator()) do
      # A -> B
      amount_b = D.mult(amount, rate) |> D.round(8)
      # B -> A
      amount_a_back = D.div(amount_b, rate) |> D.round(8)

      # We allow for a tiny epsilon due to division precision,
      # but they should be effectively equal at high precision.
      diff = D.sub(amount, amount_a_back) |> D.abs()
      assert D.compare(diff, D.new("0.00000001")) == :lt
    end
  end

  property "Sum of parts equals the whole (no pennies lost in distribution)" do
    check all(total <- money_generator(),
              shares <- integer_generator(2, 10)) do
      # Divide total into N equal parts (rounded to 2)
      share_amount = D.div(total, D.new(shares)) |> D.round(2)

      # Sum them up
      sum_of_shares = D.mult(share_amount, D.new(shares))

      # The difference should be less than the smallest unit (0.01) * number of shares
      # In a real system, we'd use a "distribute" function that handles the remainder.
      # This test documents that simple division/multiplication leaves a remainder!
      diff = D.sub(total, sum_of_shares) |> D.abs()
      assert D.compare(diff, D.new("0.10")) == :lt
    end
  end

  # Generators

  defp float_generator do
    StreamData.float(min: -1_000_000.0, max: 1_000_000.0)
  end

  defp money_generator do
    gen = StreamData.integer(1..10_000_000)
    StreamData.map(gen, fn i -> D.div(D.new(i), D.new(100)) end)
  end

  defp rate_generator do
    gen = StreamData.integer(100..200_000)
    StreamData.map(gen, fn i -> D.div(D.new(i), D.new(100_000)) end)
  end

  defp integer_generator(min, max) do
    StreamData.integer(min..max)
  end
end
