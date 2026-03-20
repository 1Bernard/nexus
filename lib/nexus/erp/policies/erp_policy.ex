defmodule Nexus.ERP.Policies.ERPPolicy do
  @moduledoc """
  Authorization policies for ERP resources (Invoices, Statements).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Identity.Projections.User.t() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Currently ERP access is open to all authenticated users in the org
  def can?(_user, _action, :erp), do: true

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
