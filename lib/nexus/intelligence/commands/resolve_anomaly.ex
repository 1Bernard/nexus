defmodule Nexus.Intelligence.Commands.ResolveAnomaly do
  @moduledoc """
  Command to resolve a detected operational or invoice anomaly.
  """
  @enforce_keys [:analysis_id, :resolution]
  defstruct [:analysis_id, :resolution]

  @type t :: %__MODULE__{
          analysis_id: String.t(),
          resolution: String.t()
        }
end
