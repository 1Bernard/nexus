defmodule Nexus.Organization.Projectors.InvitationProjector do
  @moduledoc """
  Projects Organization domain events into the Postgres read model.
  Handles invitation lifecycle: created on UserInvited, status changed on InvitationRedeemed.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Organization.InvitationProjector"

  import Ecto.Query, only: [from: 2]

  alias Nexus.Organization.Events.UserInvited
  alias Nexus.Organization.Events.InvitationRedeemed
  alias Nexus.Organization.Projections.Invitation

  project(%UserInvited{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :invitation,
      %Invitation{
        id: Ecto.UUID.generate(),
        org_id: event.org_id,
        email: event.email,
        role: event.role,
        invited_by: event.invited_by,
        invitation_token: event.invitation_token,
        invited_at: parse_datetime(event.invited_at),
        status: "pending",
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      },
      on_conflict: :nothing,
      conflict_target: [:email, :org_id]
    )
  end)

  project(%InvitationRedeemed{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :redeem_invitation,
      from(i in Invitation, where: i.invitation_token == ^event.invitation_token),
      set: [status: "redeemed", updated_at: event.redeemed_at]
    )
  end)

  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(dt) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
