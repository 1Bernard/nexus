defmodule Nexus.Treasury.Queries.VaultQuery do
  @moduledoc """
  Read model queries for Treasury Vaults.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.Vault

  @doc "Base query for Vault, scoped by organization."
  @spec base(Nexus.Types.org_id()) :: Ecto.Query.t()
  def base(org_id) do
    from(v in Vault, where: v.org_id == ^org_id)
  end

  @spec list_by_org(Nexus.Types.org_id()) :: [Vault.t()]
  def list_by_org(org_id) do
    base(org_id)
    |> Repo.all()
  end

  @spec get_vault(Nexus.Types.org_id(), Nexus.Types.binary_id()) :: Vault.t() | nil
  def get_vault(org_id, id) do
    base(org_id)
    |> where([v], v.id == ^id)
    |> Repo.one()
  end

  @spec find_vault_for_currency(Nexus.Types.org_id(), String.t()) :: Vault.t() | nil
  def find_vault_for_currency(org_id, currency) do
    base(org_id)
    |> where([v], v.currency == ^currency and v.status == "active")
    |> limit(1)
    |> Repo.one()
  end

  @spec list_all(Nexus.Types.org_id()) :: [Vault.t()]
  def list_all(org_id) do
    base(org_id)
    |> order_by([v], desc: v.updated_at)
    |> Repo.all()
  end

  @spec get_stats(Nexus.Types.org_id()) :: map()
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
