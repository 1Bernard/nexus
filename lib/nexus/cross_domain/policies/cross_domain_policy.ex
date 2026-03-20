defmodule Nexus.CrossDomain.Policies.CrossDomainPolicy do
  @moduledoc """
  Authorization policies for CrossDomain resources (Notifications).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Identity.Projections.User.t() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Notifications are generally accessible to all authenticated users
  def can?(_user, _action, :notifications), do: true

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
