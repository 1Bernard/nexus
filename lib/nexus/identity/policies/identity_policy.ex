defmodule Nexus.Identity.Policies.IdentityPolicy do
  @moduledoc """
  Authorization policies for Identity resources (Users, Settings, Sessions).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # --- Backoffice Access ---
  def can?(user, _action, :backoffice) do
    Nexus.Shared.Policy.has_role?(user, "admin")
  end

  # --- Dashboard & Settings ---
  def can?(_user, _action, :dashboard), do: true
  def can?(_user, _action, :settings), do: true

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
