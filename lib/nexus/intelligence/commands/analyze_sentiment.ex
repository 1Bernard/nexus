defmodule Nexus.Intelligence.Commands.AnalyzeSentiment do
  @moduledoc """
  Command to evaluate the sentiment of unstructured text.
  """
  @enforce_keys [:analysis_id, :org_id, :source_id, :text]
  defstruct [:analysis_id, :org_id, :source_id, :text]
end
