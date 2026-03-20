defmodule Nexus.Intelligence.Queries.AnalysisQuery do
  @moduledoc """
  Read model queries for AI Sentinel analyses.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Intelligence.Projections.Analysis
  alias Nexus.Types

  @doc """
  Returns recent analyses for an organization.
  """
  @spec list_analyses(Types.org_id(), integer()) :: [Analysis.t()]
  def list_analyses(org_id, limit \\ 50) do
    Analysis
    |> where([a], a.org_id == ^org_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns anomaly items for a specific dashboard view.
  """
  @spec list_anomalies(Types.org_id()) :: [Analysis.t()]
  def list_anomalies(org_id) do
    Analysis
    |> where([a], a.org_id == ^org_id and a.type == "anomaly")
    |> order_by([a], desc: a.flagged_at)
    |> Repo.all()
  end

  @doc """
  Returns sentiment insights.
  """
  @spec list_sentiments(Types.org_id()) :: [Analysis.t()]
  def list_sentiments(org_id) do
    Analysis
    |> where([a], a.org_id == ^org_id and a.type == "sentiment")
    |> order_by([a], desc: a.scored_at)
    |> Repo.all()
  end

  @doc """
  Returns anomaly items globally (for Admin view).
  """
  @spec list_all_anomalies() :: [Analysis.t()]
  def list_all_anomalies() do
    Analysis
    |> where([a], a.type == "anomaly")
    |> order_by([a], desc: a.flagged_at)
    |> Repo.all()
  end

  @doc """
  Returns sentiment insights globally (for Admin view).
  """
  @spec list_all_sentiments() :: [Analysis.t()]
  def list_all_sentiments() do
    Analysis
    |> where([a], a.type == "sentiment")
    |> order_by([a], desc: a.scored_at)
    |> Repo.all()
  end

  @doc """
  Returns a specific anomaly by ID, scoped by organization.
  """
  @spec get_anomaly!(Types.org_id(), Types.binary_id()) :: Analysis.t()
  def get_anomaly!(org_id, id) do
    Analysis
    |> where([a], a.org_id == ^org_id and a.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Internal system fetch by ID (unscoped by org).
  ONLY use this in System Admin dashboards.
  """
  @spec get_anomaly_system!(Types.binary_id()) :: Analysis.t()
  def get_anomaly_system!(id), do: Repo.get!(Analysis, id)
end
