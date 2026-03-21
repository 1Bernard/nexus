defmodule Nexus.Treasury.Projectors.ForecastProjector do
  @moduledoc """
  Projector for liquidity forecasts.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ForecastProjector"

  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.ForecastSnapshot

  project(%ForecastGenerated{} = event, _metadata, fn multi ->
    # Use the idempotency_key as the record ID if it's a valid UUID,
    # otherwise generate a stable one to prevent duplicate projections.
    id =
      case Ecto.UUID.cast(event.idempotency_key) do
        {:ok, uuid} -> uuid
        _ -> Nexus.Schema.generate_uuidv7()
      end

    attrs = %{
      id: id,
      org_id: event.org_id,
      currency: event.currency,
      horizon_days: event.horizon_days,
      data_points: event.predictions,
      generated_at: Nexus.Schema.parse_datetime(event.generated_at)
    }

    multi
    |> Ecto.Multi.insert(
      :forecast_snapshot,
      ForecastSnapshot.changeset(%ForecastSnapshot{}, attrs),
      on_conflict: :nothing,
      conflict_target: :id
    )
  end)
end
