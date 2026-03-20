defmodule Nexus.Intelligence.Commands.ResolveAnomaly do
  @moduledoc """
  Command to resolve a detected operational or invoice anomaly.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          resolution: String.t(),
          resolved_at: Types.datetime()
        }

  @enforce_keys [:analysis_id, :org_id, :resolution, :resolved_at]
  defstruct [:analysis_id, :org_id, :resolution, :resolved_at]
end
