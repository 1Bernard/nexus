defmodule Nexus.CrossDomain do
  @moduledoc """
  The CrossDomain context.
  Handles global system events, notifications, and cross-cutting concerns.
  """
  alias Nexus.Repo
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Types

  alias Nexus.CrossDomain.Queries.NotificationQuery
  alias Nexus.CrossDomain.Queries.SearchQuery

  @doc """
  Lists notifications for a user/organization.
  """
  @spec list_notifications(Types.org_id(), Types.binary_id(), integer()) :: [Notification.t()]
  def list_notifications(org_id, user_id, limit \\ 20)
  def list_notifications(nil, _user_id, _limit), do: []
  def list_notifications(_org_id, nil, _limit), do: []

  def list_notifications(org_id, user_id, limit) do
    NotificationQuery.base(org_id)
    |> NotificationQuery.with_context()
    |> NotificationQuery.for_user(user_id)
    |> NotificationQuery.newest_first()
    |> NotificationQuery.limit_results(limit)
    |> Repo.all()
  end

  @doc """
  Searches across multiple domains (Invoices, Statements) for the Command Palette.
  Returns a list of result maps with `:path`, `:label`, `:detail`, and `:icon` keys.
  """
  @spec search(Types.org_id(), String.t()) :: [map()]
  def search(_org_id, term) when byte_size(term) < 3, do: []

  def search(org_id, term) do
    invoice_results = Repo.all(SearchQuery.search_invoices(org_id, term))
    statement_results = Repo.all(SearchQuery.search_statements(org_id, term))

    invoice_results ++ statement_results
  end
end
