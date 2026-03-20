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
    amount: Decimal.new("1000.00"),
    currency: "EUR",
    status: "matched",
    due_date: now,
    created_at: now,
    updated_at: now
  })
end

# Partial
for i <- 1..38 do
  Repo.insert!(%Invoice{
    id: Ecto.UUID.generate(),
    org_id: org_id,
    entity_id: "ENT-P-#{i}",
    sap_document_number: "SAP-P-#{i}",
    amount: Decimal.new("500.00"),
    currency: "EUR",
    status: "partial",
    due_date: now,
    created_at: now,
    updated_at: now
  })
end

# Unmatched
for i <- 1..15 do
  Repo.insert!(%Invoice{
    id: Ecto.UUID.generate(),
    org_id: org_id,
    entity_id: "ENT-U-#{i}",
    sap_document_number: "SAP-U-#{i}",
    amount: Decimal.new("2500.00"),
    currency: "EUR",
    status: "unmatched",
    due_date: now,
    created_at: now,
    updated_at: now
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
    calculated_at: now,
    created_at: now,
    updated_at: now
  })
end

IO.puts("Dashboard data seeding complete.")

# --- Seed Identity Domain (Demo Users) ---
IO.puts("Seeding Identity Domain users...")

admin_id = "019c9247-5ee0-7732-9423-5627160214ce"

admin_cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
  user_id: admin_id,
  org_id: org_id,
  email: "admin@nexus-platform.io",
  display_name: "Nexus System Admin",
  registered_at: now
}

elena_id = Nexus.Schema.generate_uuidv7()

elena_cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
  user_id: elena_id,
  org_id: org_id,
  email: "elena@global-corp.com",
  display_name: "Elena (Global Corp App)",
  registered_at: now
}

case Nexus.App.dispatch(admin_cmd) do
  :ok -> IO.puts("Successfully registered admin@nexus-platform.io in the EventStore.")
  {:error, :already_registered} -> IO.puts("Admin already registered.")
  {:error, reason} -> IO.puts("Failed to register admin: \#{inspect(reason)}")
end

case Nexus.App.dispatch(elena_cmd) do
  :ok -> IO.puts("Successfully registered elena@global-corp.com in the EventStore.")
  {:error, :already_registered} -> IO.puts("Elena already registered.")
  {:error, reason} -> IO.puts("Failed to register Elena: \#{inspect(reason)}")
end

IO.puts("Identity Domain seeding complete.")

# --- Seed Treasury Vaults & Liquidity Positions ---
alias Nexus.Treasury.Projections.{Vault, LiquidityPosition}

IO.puts("Seeding Treasury Vaults and Liquidity...")

# Clean up
Repo.delete_all(Vault)
Repo.delete_all(LiquidityPosition)

vault_configs = [
  %{
    name: "DB Main Operating (EUR)",
    bank_name: "Deutsche Bank",
    currency: "EUR",
    amount: "642500.00"
  },
  %{
    name: "HSBC Settlement (EUR)",
    bank_name: "HSBC",
    currency: "EUR",
    amount: "200000.00"
  },
  %{
    name: "Chase Treasury (USD)",
    bank_name: "J.P. Morgan Chase",
    currency: "USD",
    amount: "1500000.00"
  }
]

for config <- vault_configs do
  vault_id = Ecto.UUID.generate()

  # 1. Create the Vault Projection
  Repo.insert!(%Vault{
    id: vault_id,
    org_id: org_id,
    name: config.name,
    bank_name: config.bank_name,
    currency: config.currency,
    balance: Decimal.new(config.amount),
    provider: "Nexus Direct",
    status: "active",
    created_at: now,
    updated_at: now
  })
end

# 2. Create aggregated Liquidity Positions (one per currency)
# Sum EUR (642,500 + 200,000 = 842,500)
Repo.insert!(%LiquidityPosition{
  id: Ecto.UUID.generate(),
  org_id: org_id,
  currency: "EUR",
  amount: Decimal.new("842500.00"),
  created_at: now,
  updated_at: now
})

# Sum USD (1,500,000)
Repo.insert!(%LiquidityPosition{
  id: Ecto.UUID.generate(),
  org_id: org_id,
  currency: "USD",
  amount: Decimal.new("1500000.00"),
  created_at: now,
  updated_at: now
})

IO.puts("Treasury seeding complete: 3 Vaults and 2 Aggregated Liquidity Positions added.")
