defmodule Nexus.Treasury.Events.ExposureCalculated do
  @moduledoc """
  Event emitted when FX risk exposure is calculated for a subsidiary.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
  defstruct [:org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
end
