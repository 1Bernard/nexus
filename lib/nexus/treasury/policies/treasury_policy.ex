defmodule Nexus.Treasury.Policies.TreasuryPolicy do
  @moduledoc """
  Authorization policies for Treasury resources (Vaults, Transfers, Reconciliations).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # --- Vault Permissions ---
  def can?(user, _action, :vaults) do
    user.role in [:treasury_ops, "treasury_ops", :system_admin, "system_admin"]
  end

  def can?(user, action, :vault) when action in [:simulate_rebalance, :register_vault] do
    user.role in [:treasury_ops, "treasury_ops", :system_admin, "system_admin"]
  end

  # --- Reconciliation Permissions ---
  def can?(user, action, :reconciliation)
      when action in [:confirm, :reverse, :approve, :reject] do
    user.role in [:treasury_ops, "treasury_ops", :system_admin, "system_admin"]
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
