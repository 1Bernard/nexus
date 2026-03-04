defmodule Nexus.Intelligence.Queries.AnalysisQuery do
  @moduledoc """
  Read model queries for AI Sentinel analyses.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Intelligence.Projections.Analysis

  @doc """
  Returns recent analyses for an organization.
  """
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
  def list_anomalies(org_id) do
    Analysis
    |> where([a], a.org_id == ^org_id and a.type == "anomaly")
    |> order_by([a], desc: a.flagged_at)
    |> Repo.all()
  end

  @doc """
  Returns sentiment insights.
  """
  def list_sentiments(org_id) do
    Analysis
    |> where([a], a.org_id == ^org_id and a.type == "sentiment")
    |> order_by([a], desc: a.scored_at)
    |> Repo.all()
  end
end
