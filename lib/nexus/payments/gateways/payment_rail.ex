defmodule Nexus.Payments.Gateways.PaymentRail do
  @moduledoc """
  Behavior defining the interface for external payment execution.
  """
  alias Nexus.Types

  @callback execute_transfer(
              transfer_id :: Types.binary_id(),
              amount :: Types.money(),
              currency :: Types.currency(),
              recipient_data :: map()
            ) :: {:ok, reference :: String.t()} | {:error, reason :: any()}

  @callback verify_transfer(transfer_id :: Types.binary_id()) ::
              {:ok, status :: atom()} | {:error, reason :: any()}
end
