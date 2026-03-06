defmodule Nexus.Intelligence.Commands.ResolveAnomaly do
  @moduledoc """
  Command to resolve a detected operational or invoice anomaly.
  """
  @enforce_keys [:analysis_id, :org_id, :resolution, :resolved_at]
  defstruct [:analysis_id, :org_id, :resolution, :resolved_at]

  @type t :: %__MODULE__{
          analysis_id: String.t(),
          org_id: String.t(),
          resolution: String.t(),
          resolved_at: DateTime.t()
        }
end
