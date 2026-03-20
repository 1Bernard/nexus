defmodule Nexus.Payments.Policies.PaymentsPolicy do
  @moduledoc """
  Authorization policies for Payment resources (External Payments, Bulk Payments).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Basic payment viewing for all org users
  def can?(_user, :view, :payments), do: true

  # Initiating and approving payments requires treasury_ops or system_admin
  def can?(user, :initiate, :payments) do
    user.role in [:treasury_ops, "treasury_ops", :system_admin, "system_admin"]
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
