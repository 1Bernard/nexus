defmodule Nexus.Intelligence.Events.AnomalyDetected do
  @moduledoc """
  Emitted when the AI Sentinel flags an invoice as an anomaly.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          type: atom(),
          resource_id: Types.binary_id() | nil,
          invoice_id: Types.binary_id() | nil,
          score: float(),
          reason: String.t(),
          flagged_at: Types.datetime()
        }
  defstruct [:analysis_id, :org_id, :type, :resource_id, :invoice_id, :score, :reason, :flagged_at]
end
