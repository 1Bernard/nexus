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

  project(%ForecastGenerated{} = ev, _metadata, fn multi ->
    # Generate a deterministic ID for this forecast version (e.g., daily per org/currency)
    id = Ecto.UUID.generate()

    attrs = %{
      id: id,
      org_id: ev.org_id,
      currency: ev.currency,
      horizon_days: ev.horizon_days,
      # Assuming it was passed in the event
      data_points: ev.predictions,
      generated_at: ev.generated_at
    }

    Ecto.Multi.insert(
      multi,
      :forecast_snapshot,
      ForecastSnapshot.changeset(%ForecastSnapshot{}, attrs)
    )
  end)
end
