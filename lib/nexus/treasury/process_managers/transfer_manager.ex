defmodule Nexus.Treasury.ProcessManagers.TransferManager do
  @moduledoc """
  Coordinates the multi-domain Funds Transfer lifecycle.
  Bridges Identity (Step-Up) and Treasury (Execution).
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.TransferManager"

  @derive Jason.Encoder
  defstruct [:transfer_id, :org_id, :status]

  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}
  alias Nexus.Identity.Events.StepUpVerified
  alias Nexus.Treasury.Commands.{AuthorizeTransfer, ExecuteTransfer}

  def interested?(%TransferInitiated{transfer_id: id}), do: {:start!, id}
  def interested?(%StepUpVerified{action_id: id}), do: {:continue!, id}
  def interested?(%TransferAuthorized{transfer_id: id}), do: {:continue!, id}
  def interested?(%TransferExecuted{transfer_id: id}), do: {:stop!, id}

  # --- Handle Events (Emit Commands) ---

  def handle(%__MODULE__{}, %TransferInitiated{status: "authorized"} = event) do
    %ExecuteTransfer{
      transfer_id: event.transfer_id,
      org_id: event.org_id,
      executed_at: DateTime.utc_now()
    }
  end

  def handle(%__MODULE__{}, %TransferInitiated{status: "pending_authorization"}), do: []

  def handle(%__MODULE__{status: "pending_authorization"}, %StepUpVerified{} = event) do
    %AuthorizeTransfer{
      transfer_id: event.action_id,
      org_id: event.org_id,
      actor_email: "verified-user@nexus.ai",
      authorized_at: event.verified_at
    }
  end

  def handle(%__MODULE__{}, %TransferAuthorized{} = event) do
    %ExecuteTransfer{
      transfer_id: event.transfer_id,
      org_id: event.org_id,
      executed_at: DateTime.utc_now()
    }
  end

  def handle(%__MODULE__{}, %TransferExecuted{}), do: []

  # --- Mutate State ---

  def apply(%__MODULE__{} = pm, %TransferInitiated{} = event) do
    %__MODULE__{pm | transfer_id: event.transfer_id, org_id: event.org_id, status: event.status}
  end

  def apply(%__MODULE__{} = pm, %TransferAuthorized{}) do
    %__MODULE__{pm | status: "authorized"}
  end

  def apply(%__MODULE__{} = pm, %TransferExecuted{}) do
    %__MODULE__{pm | status: "executed"}
  end
end
