defmodule Nexus.Intelligence.Policies.IntelligencePolicy do
  @moduledoc """
  Authorization policies for AI Sentinel resources (Anomalies, Sentiments).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Compliance / Intelligence access
  def can?(user, _action, :compliance) do
    Nexus.Shared.Policy.has_role?(user, "auditor")
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
