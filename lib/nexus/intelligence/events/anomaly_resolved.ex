defmodule Nexus.Intelligence.Events.AnomalyResolved do
  @moduledoc """
  Event emitted when an anomaly is resolved by an administrator.
  """
  @derive {Jason.Encoder, only: [:analysis_id, :resolution, :resolved_at]}
  @enforce_keys [:analysis_id, :resolution, :resolved_at]
  defstruct [:analysis_id, :resolution, :resolved_at]

  @type t :: %__MODULE__{
          analysis_id: String.t(),
          resolution: String.t(),
          resolved_at: DateTime.t()
        }
end
