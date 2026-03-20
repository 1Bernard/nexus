defmodule Nexus.Intelligence.Commands.AnalyzeSentiment do
  @moduledoc """
  Command to evaluate the sentiment of unstructured text.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          source_id: Types.binary_id(),
          text: String.t(),
          scored_at: Types.datetime()
        }

  @enforce_keys [:analysis_id, :org_id, :source_id, :text, :scored_at]
  defstruct [:analysis_id, :org_id, :source_id, :text, :scored_at]
end
