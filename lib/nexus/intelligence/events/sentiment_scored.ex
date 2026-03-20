defmodule Nexus.Intelligence.Events.SentimentScored do
  @moduledoc """
  Emitted when unstructured text has been scored for sentiment.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          source_id: Types.binary_id(),
          sentiment: String.t(),
          confidence: float(),
          scored_at: Types.datetime()
        }
  defstruct [:analysis_id, :org_id, :source_id, :sentiment, :confidence, :scored_at]
end
