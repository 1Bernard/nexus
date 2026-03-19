# Seeding High-Fidelity Vaults for Nexus Treasury
alias Nexus.Treasury
alias Nexus.Repo
alias Nexus.Organization.Projections.Tenant

# Ensure we have at least one organization
org_id =
  case Repo.all(Tenant) do
    [tenant | _] -> tenant.org_id
    [] -> "018d1a1e-8e7c-7d9a-8b0c-1e2f3g4h5i6j"
  end

IO.puts("Seeding Vaults for Org: #{org_id}...")

vaults = [
  %{
    name: "JPMorgan Chase Operating",
    bank_name: "JPMorgan Chase",
    currency: "USD",
    provider: "paystack", # Using paystack as a default institutional provider for demo
    account_number: "•••• 8821",
    balance: Decimal.new("2450000.00")
  },
  %{
    name: "HSBC EUR Liquidity",
    bank_name: "HSBC UK",
    currency: "EUR",
    provider: "manual",
    iban: "GB29 HSBC 6016 1331 9268 11",
    balance: Decimal.new("1820000.00")
  },
  %{
    name: "Barclays GBP Settlement",
    bank_name: "Barclays Bank",
    currency: "GBP",
    provider: "manual",
    account_number: "•••• 4421",
    balance: Decimal.new("940500.00")
  }
]

Enum.each(vaults, fn attrs ->
  # 1. Register the vault
  vault_id = Nexus.Schema.generate_uuidv7()
  
  Treasury.register_vault(%{
    org_id: org_id,
    name: attrs.name,
    bank_name: attrs.bank_name,
    account_number: Map.get(attrs, :account_number),
    iban: Map.get(attrs, :iban),
    currency: attrs.currency,
    provider: attrs.provider
  })

  # 2. Sync initial balance (Wait a bit for projector to catch up if running in a script)
  # But since dispatch is async by default unless consistency: :strong, we just send it.
  Treasury.sync_vault_balance(%{
    vault_id: vault_id,
    org_id: org_id,
    amount: attrs.balance,
    currency: attrs.currency
  })
  
  IO.puts("Registered: #{attrs.name} (#{attrs.currency})")
end)

IO.puts("Vault seeding complete.")
