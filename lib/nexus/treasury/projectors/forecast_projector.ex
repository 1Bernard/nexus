defmodule Nexus.Treasury.Projectors.ForecastProjector do
  @moduledoc """
  Projector for liquidity forecasts.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ForecastProjector",
    consistency: :strong

  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.ForecastSnapshot

  project(%ForecastGenerated{} = event, _metadata, fn multi ->
    # Generate a deterministic ID for this forecast version (e.g., daily per org/currency)
    id = Nexus.Schema.generate_uuidv7()

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
      ForecastSnapshot.changeset(%ForecastSnapshot{}, attrs)
    )
  end)
end
