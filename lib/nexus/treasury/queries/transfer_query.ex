defmodule Nexus.Treasury.Queries.TransferQuery do
  @moduledoc """
  Query module for fetching Transfer projections.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.Transfer

  @doc "Base query for Transfer, scoped by organization."
  @spec base(Nexus.Types.org_id()) :: Ecto.Query.t()
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    if org_id == :all do
      from(t in Transfer)
    else
      from(t in Transfer, where: t.org_id == ^org_id)
    end
  end

  @doc """
  Lists recent autonomous rebalancing activities for an organization.
  """
  @spec list_rebalance_activity(Nexus.Types.org_id(), integer()) :: [Transfer.t()]
  def list_rebalance_activity(org_id, limit \\ 5) do
    # Use the zero UUID for system-initiated rebalances
    system_id = "00000000-0000-0000-0000-000000000000"

    base(org_id)
    |> where([t], t.user_id == ^system_id)
    |> order_by([t], desc: t.created_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists all recent transfers for an organization.
  """
  @spec list_recent(Nexus.Types.org_id(), integer()) :: [Transfer.t()]
  def list_recent(org_id, limit \\ 10) do
    base(org_id)
    |> order_by([t], desc: t.created_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
