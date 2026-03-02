defmodule Nexus.Intelligence.Events.AnomalyDetected do
  @moduledoc """
  Emitted when the AI Sentinel flags an invoice as an anomaly.
  """
  @derive Jason.Encoder
  @enforce_keys [:analysis_id, :org_id, :invoice_id, :score, :reason, :flagged_at]
  defstruct [:analysis_id, :org_id, :invoice_id, :score, :reason, :flagged_at]
end
