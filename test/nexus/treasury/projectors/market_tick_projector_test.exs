defmodule Nexus.Treasury.MarketTickProjectorTest do
  use Nexus.DataCase, async: false

  @tag :no_sandbox
  alias Nexus.Treasury.Projectors.MarketTickProjector
  alias Nexus.Treasury.Events.MarketTickRecorded
  alias Nexus.Treasury.Projections.MarketTick
  alias Nexus.Repo
  import Ecto.Query

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Repo.delete_all(MarketTick)
    end)

    :ok
  end

  test "projects a MarketTickRecorded event with a generated UUIDv7" do
    event = %MarketTickRecorded{
      pair: "EUR/USD",
      price: "1.0850",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    metadata = %{event_number: 1, handler_name: "Treasury.MarketTickProjector"}

    # Run the projector handle function
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      assert :ok = MarketTickProjector.handle(event, metadata)

      # Verify the projected tick
      tick = Repo.one(from t in MarketTick, where: t.pair == "EUR/USD")
      assert tick != nil
      assert %Decimal{} = tick.price
      assert Decimal.equal?(tick.price, Decimal.new("1.0850"))
      assert tick.id != nil

      assert {:ok, _} = Ecto.UUID.cast(tick.id)
    end)
  end
end
