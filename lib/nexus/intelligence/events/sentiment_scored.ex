defmodule Nexus.Intelligence.Events.SentimentScored do
  @moduledoc """
  Emitted when unstructured text has been scored for sentiment.
  """
  @derive Jason.Encoder
  @enforce_keys [:analysis_id, :org_id, :source_id, :sentiment, :confidence, :scored_at]
  defstruct [:analysis_id, :org_id, :source_id, :sentiment, :confidence, :scored_at]
end
