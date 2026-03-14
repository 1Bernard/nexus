defmodule Nexus.Treasury.HeatmapTest do
  use Nexus.DataCase
  alias Nexus.Treasury
  alias Nexus.Treasury.Projections.ExposureSnapshot

  describe "list_exposure_heatmap/1" do
    test "returns fallback defaults when no snapshots exist" do
      org_id = Ecto.UUID.generate()
      result = Treasury.list_exposure_heatmap(org_id)

      assert result.subsidiaries == ["Munich HQ", "Tokyo Branch", "Corporate Operations"]
      assert result.currencies == ["EUR", "USD", "GBP", "JPY", "CHF"]
      assert result.data == %{}
    end

    test "returns dynamic subsidiaries and currencies when snapshots exist" do
      org_id = Ecto.UUID.generate()

      # Insert some test snapshots
      Repo.insert!(%ExposureSnapshot{
        id: "Berlin-USD",
        org_id: org_id,
        subsidiary: "Berlin",
        currency: "USD",
        exposure_amount: Decimal.new("1000.00"),
        calculated_at: DateTime.utc_now()
      })

      Repo.insert!(%ExposureSnapshot{
        id: "Paris-EUR",
        org_id: org_id,
        subsidiary: "Paris",
        currency: "EUR",
        exposure_amount: Decimal.new("2000.00"),
        calculated_at: DateTime.utc_now()
      })

      result = Treasury.list_exposure_heatmap(org_id)

      assert Enum.sort(result.subsidiaries) == ["Berlin", "Paris"]
      assert Enum.sort(result.currencies) == ["EUR", "USD"]
      assert result.data["Berlin"]["USD"] == Decimal.new("1000.00")
      assert result.data["Paris"]["EUR"] == Decimal.new("2000.00")
    end
  end
end
