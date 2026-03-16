defmodule Nexus.Identity.Events.SettingsUpdated do
  @moduledoc """
  Event emitted when user preferences are updated.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          locale: String.t(),
          timezone: String.t(),
          notifications_enabled: boolean(),
          updated_at: Types.datetime()
        }

  defstruct [:org_id, :user_id, :locale, :timezone, :notifications_enabled, :updated_at]
end
