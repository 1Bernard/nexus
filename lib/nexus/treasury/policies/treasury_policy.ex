defmodule Nexus.Treasury.Policies.TreasuryPolicy do
  @moduledoc """
  Authorization policies for Treasury resources (Vaults, Transfers, Reconciliations).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # --- General Treasury Ops ---
  def can?(user, _action, :treasury_ops) do
    Nexus.Shared.Policy.has_role?(user, "treasury_ops")
  end

  # --- Vault Permissions ---
  def can?(user, _action, :vaults) do
    Nexus.Shared.Policy.has_role?(user, "treasury_ops")
  end

  def can?(user, action, :vault) when action in [:simulate_rebalance, :register_vault] do
    Nexus.Shared.Policy.has_role?(user, "treasury_ops")
  end

  # --- Reconciliation Permissions ---
  def can?(user, action, :reconciliation)
      when action in [:confirm, :reverse, :approve, :reject] do
    Nexus.Shared.Policy.has_role?(user, "treasury_ops")
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
