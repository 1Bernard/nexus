defmodule Nexus.Identity.Commands.UpdateSettings do
  @moduledoc """
  Command to update user preferences and localization settings.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          locale: String.t(),
          timezone: String.t(),
          notifications_enabled: boolean(),
          updated_at: Types.datetime()
        }

  @enforce_keys [:org_id, :user_id, :updated_at]
  defstruct [:org_id, :user_id, :locale, :timezone, :notifications_enabled, :updated_at]
end
