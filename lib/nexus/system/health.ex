defmodule Nexus.System.Health do
  @moduledoc """
  Provides real-time system health metrics for the Platform Backoffice.
  """
  import Ecto.Query
  alias Nexus.Repo

  @doc """
  Returns a summarized map of system health metrics.
  """
  def get_summary do
    %{
      active_tenants: count_active_tenants(),
      event_store_lag: calculate_event_store_lag(),
      system_health: determine_system_health()
    }
  end

  defp count_active_tenants do
    Nexus.Organization.Projections.Tenant
    |> where([t], t.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  defp calculate_event_store_lag do
    # 1. Get Event Store Head (stream_version of $all stream)
    # Using raw SQL for the event_store schema as it's not managed by our typical Ecto schemas
    es_head =
      case Repo.query("SELECT stream_version FROM event_store.streams WHERE stream_uuid = '$all'") do
        {:ok, %{rows: [[version]]}} -> version
        _ -> 0
      end

    # 2. Get Projection Head (max last_seen_event_number)
    projection_head =
      case Repo.query("SELECT MAX(last_seen_event_number) FROM public.projection_versions") do
        {:ok, %{rows: [[version]]}} -> version || 0
        _ -> 0
      end

    # 3. Lag is the distance
    max(0, es_head - projection_head)
  end

  defp determine_system_health do
    lag = calculate_event_store_lag()

    cond do
      lag > 1000 -> "Degraded"
      lag > 500 -> "Warning"
      true -> "Nominal"
    end
  end
end
