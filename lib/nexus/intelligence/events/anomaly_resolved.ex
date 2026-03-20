defmodule Nexus.Intelligence.Events.AnomalyResolved do
  @moduledoc """
  Event emitted when an anomaly is resolved by an administrator.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          resolution: String.t(),
          resolved_at: Types.datetime()
        }

  defstruct [:analysis_id, :org_id, :resolution, :resolved_at]
end
