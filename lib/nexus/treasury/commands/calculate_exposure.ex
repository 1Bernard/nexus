defmodule Nexus.Treasury.Commands.CalculateExposure do
  @moduledoc """
  Command to record a calculated risk exposure for a given subsidiary.
  """
  defstruct [:id, :org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
end
