defmodule Nexus.Treasury.Queries.VaultQuery do
  @moduledoc """
  Read model queries for Treasury Vaults.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.Vault

  def list_by_org(org_id) do
    from(v in Vault, where: v.org_id == ^org_id)
    |> Repo.all()
  end

  def get_vault(id) do
    Repo.get(Vault, id)
  end

  def find_vault_for_currency(org_id, currency) do
    from(v in Vault, where: v.org_id == ^org_id and v.currency == ^currency and v.status == "active")
    |> limit(1)
    |> Repo.one()
  end

  def list_all(org_id) do
    from(v in Vault, where: v.org_id == ^org_id, order_by: [desc: v.updated_at])
    |> Repo.all()
  end

  def get_stats(org_id) do
    list_all(org_id)
    |> Enum.reduce(%{total_usd: Decimal.new(0), total_eur: Decimal.new(0), count: 0}, fn v, acc ->
      case v.currency do
        "USD" -> %{acc | total_usd: Decimal.add(acc.total_usd, v.balance), count: acc.count + 1}
        "EUR" -> %{acc | total_eur: Decimal.add(acc.total_eur, v.balance), count: acc.count + 1}
        _ -> %{acc | count: acc.count + 1}
      end
    end)
  end
end
