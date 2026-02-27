defmodule Nexus.Treasury.Commands.EvaluateExposurePolicy do
  @moduledoc """
  Command to evaluate current exposure against an organization's threshold.
  """
  @enforce_keys [:policy_id, :org_id, :currency_pair, :exposure_amount]
  defstruct [:policy_id, :org_id, :currency_pair, :exposure_amount]
end
