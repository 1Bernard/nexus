alias Nexus.Repo
alias Nexus.Treasury.Projections.MarketTick

IO.puts("Seeding market data...")

# Clean up existing ticks to avoid duplicates in dev
Repo.delete_all(MarketTick)

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

# Seed 2,000 ticks for EUR/USD to create realistic OHLC buckets
base_price = 1.0850
IO.puts("Generating 2,000 ticks...")

# We'll use a simple state to track price across iterations
{ticks, _final_price} =
  Enum.map_reduce(1..2000, base_price, fn i, current_price ->
    # Random walk: small movement up or down
    change = (:rand.uniform() - 0.5) * 0.001
    new_price = current_price + change

    # Spread ticks across the last ~14 hours (1 tick every 25 seconds)
    tick_time = DateTime.add(now, -(2000 - i) * 25, :second)

    tick = %MarketTick{
      pair: "EUR/USD",
      price: Decimal.from_float(new_price),
      tick_time: tick_time
    }

    {tick, new_price}
  end)

# Batch insert for performance
Enum.chunk_every(ticks, 500)
|> Enum.each(fn chunk ->
  Repo.insert_all(
    MarketTick,
    Enum.map(chunk, fn t ->
      Map.from_struct(t)
      |> Map.delete(:__meta__)
      |> Map.put(:id, Ecto.UUID.generate())
      |> Map.put(:created_at, now)
      |> Map.put(:updated_at, now)
    end)
  )
end)

IO.puts("Seed complete: 2,000 high-density ticks inserted for EUR/USD.")

# --- Seed Dashboard Data (Risk & Invoices) ---
alias Nexus.ERP.Projections.Invoice
alias Nexus.Treasury.Projections.ExposureSnapshot

# Global Org ID for Dev
org_id = "00000000-0000-0000-0000-000000000000"

# 1. Seed Invoices for matching stats
IO.puts("Seeding invoices...")
Repo.delete_all(Invoice)

# Matched
for i <- 1..847 do
  Repo.insert!(%Invoice{
    id: Ecto.UUID.generate(),
    org_id: org_id,
    entity_id: "ENT-#{i}",
    sap_document_number: "SAP-M-#{i}",
    amount: "1000.00",
    currency: "EUR",
    status: "matched"
  })
end

# Partial
for i <- 1..38 do
  Repo.insert!(%Invoice{
    id: Ecto.UUID.generate(),
    org_id: org_id,
    entity_id: "ENT-P-#{i}",
    sap_document_number: "SAP-P-#{i}",
    amount: "500.00",
    currency: "EUR",
    status: "partial"
  })
end

# Unmatched
for i <- 1..15 do
  Repo.insert!(%Invoice{
    id: Ecto.UUID.generate(),
    org_id: org_id,
    entity_id: "ENT-U-#{i}",
    sap_document_number: "SAP-U-#{i}",
    amount: "2500.00",
    currency: "EUR",
    status: "unmatched"
  })
end

# 2. Seed Exposure Snapshots
IO.puts("Seeding exposure snapshots...")
Repo.delete_all(ExposureSnapshot)

subsidiaries = ["Munich HQ", "Tokyo Branch", "London Ltd"]
currencies = ["EUR", "USD", "GBP", "JPY", "CHF"]

for sub <- subsidiaries, cur <- currencies do
  # Random exposure between 10k and 1.5M
  amount = :rand.uniform(150) * 10_000

  Repo.insert!(%ExposureSnapshot{
    id: "#{sub}-#{cur}",
    org_id: org_id,
    subsidiary: sub,
    currency: cur,
    exposure_amount: Decimal.new(amount),
    calculated_at: now
  })
end

IO.puts("Dashboard data seeding complete.")
