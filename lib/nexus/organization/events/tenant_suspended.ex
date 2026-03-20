defmodule Nexus.Organization.Events.TenantSuspended do
  @moduledoc """
  Event emitted when a system administrator suspends a tenant organisation.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          suspended_by: String.t(),
          reason: String.t(),
          suspended_at: Types.datetime()
        }

  defstruct [:org_id, :suspended_by, :reason, :suspended_at]
end
