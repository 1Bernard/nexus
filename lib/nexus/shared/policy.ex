defmodule Nexus.Shared.Policy do
  @moduledoc """
  Behavior definition for domain-specific authorization policies.
  """

  @type user :: %{role: atom() | String.t(), org_id: binary() | nil}
  @type action :: atom()
  @type resource :: any()

  @callback can?(user() | nil, action(), resource()) :: boolean()

  @doc """
  Evaluates authorization for the given user, action, and target.
  """
  @spec can?(user() | nil, action(), resource()) :: boolean()
  def can?(%{role: roles} = user, action, target) when is_list(roles) do
    # Handle legacy list roles for backward compatibility during transition
    role = List.first(roles)
    can?(%{user | role: role}, action, target)
  end

  def can?(%{role: "system_admin"}, _action, _target), do: true
end
