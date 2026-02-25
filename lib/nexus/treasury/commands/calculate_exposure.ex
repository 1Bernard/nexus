defmodule Nexus.Treasury.Commands.CalculateExposure do
  @moduledoc """
  Command to record a calculated risk exposure for a given subsidiary.
  """
  @enforce_keys [:id, :org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
  defstruct [:id, :org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
end
