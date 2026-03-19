defmodule Nexus.Treasury.Projectors.VaultProjector do
  @moduledoc """
  Projector for the Vault aggregate.
  Updates the `treasury_vaults` read model.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.VaultProjector",
    consistency: :strong

  alias Nexus.Treasury.Events.{VaultRegistered, VaultBalanceSynced, VaultDebited, VaultCredited}
  alias Nexus.Treasury.Projections.Vault

  project(%VaultRegistered{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :vault, %Vault{
      id: event.vault_id,
      org_id: event.org_id,
      name: event.name,
      bank_name: event.bank_name,
      account_number: event.account_number,
      iban: event.iban,
      currency: event.currency,
      provider: event.provider,
      status: "active",
      balance: Decimal.new(0)
    })
  end)

  project(%VaultBalanceSynced{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :vault, query(event.vault_id), set: [balance: event.amount])
  end)

  project(%VaultDebited{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :vault, query(event.vault_id), inc: [balance: Decimal.negate(event.amount)])
  end)

  project(%VaultCredited{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :vault, query(event.vault_id), inc: [balance: event.amount])
  end)

  defp query(id) do
    from(v in Vault, where: v.id == ^id)
  end
end
