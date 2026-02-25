defmodule Nexus.Treasury.Aggregates.Exposure do
  @moduledoc """
  CQRS Aggregate for managing calculated FX risk exposure per subsidiary.
  """
  defstruct [:id, :org_id, :subsidiary, :currency, :last_exposure_amount]

  alias Nexus.Treasury.Commands.CalculateExposure
  alias Nexus.Treasury.Events.ExposureCalculated

  @doc """
  Executes the CalculateExposure command.
  """
  def execute(%__MODULE__{} = _state, %CalculateExposure{} = cmd) do
    %ExposureCalculated{
      org_id: cmd.org_id,
      subsidiary: cmd.subsidiary,
      currency: cmd.currency,
      exposure_amount: cmd.exposure_amount,
      timestamp: cmd.timestamp || DateTime.utc_now()
    }
  end

  @doc """
  Applies the ExposureCalculated event to mutate the aggregate state.
  """
  def apply(%__MODULE__{} = state, %ExposureCalculated{} = event) do
    %{
      state
      | id: "#{event.subsidiary}-#{event.currency}",
        org_id: event.org_id,
        subsidiary: event.subsidiary,
        currency: event.currency,
        last_exposure_amount: event.exposure_amount
    }
  end
end
