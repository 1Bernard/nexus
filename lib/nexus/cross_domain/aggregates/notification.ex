defmodule Nexus.CrossDomain.Aggregates.Notification do
  @moduledoc """
  The Notification aggregate.
  Manages the lifecycle of a single notification.
  """
  alias Nexus.CrossDomain.Commands.{CreateNotification, MarkNotificationRead}
  alias Nexus.CrossDomain.Events.{NotificationCreated, NotificationRead}
  alias Nexus.Types

  @type t :: %__MODULE__{
          id: Types.binary_id() | nil,
          org_id: Types.org_id() | nil,
          user_id: Types.binary_id() | nil,
          status: :unread | :read | nil
        }
  defstruct [:id, :org_id, :user_id, :status]

  # --- Execution ---

  @spec execute(t(), CreateNotification.t() | MarkNotificationRead.t()) ::
          struct() | [struct()]
  def execute(%__MODULE__{id: nil}, %CreateNotification{} = cmd) do
    %NotificationCreated{
      id: cmd.id,
      org_id: cmd.org_id,
      user_id: cmd.user_id,
      type: cmd.type,
      title: cmd.title,
      body: cmd.body,
      metadata: cmd.metadata,
      timestamp: Nexus.Schema.utc_now()
    }
  end

  def execute(%__MODULE__{status: :read}, %MarkNotificationRead{}), do: []

  def execute(%__MODULE__{id: id} = state, %MarkNotificationRead{} = _cmd) when not is_nil(id) do
    %NotificationRead{
      id: state.id,
      org_id: state.org_id,
      user_id: state.user_id,
      read_at: Nexus.Schema.utc_now()
    }
  end

  # --- State Transitions ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = state, %NotificationCreated{} = event) do
    %{state | id: event.id, org_id: event.org_id, user_id: event.user_id, status: :unread}
  end

  def apply(%__MODULE__{} = state, %NotificationRead{}) do
    %{state | status: :read}
  end
end
