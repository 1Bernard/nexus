defmodule Nexus.Treasury.Projectors.ForecastProjector do
  @moduledoc """
  Projector for liquidity forecasts.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ForecastProjector"

  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.Forecast

  project(%ForecastGenerated{} = ev, _metadata, fn multi ->
    # Broadcast to PubSub for LiveView updates
    Phoenix.PubSub.broadcast(Nexus.PubSub, "forecasts:#{ev.org_id}", {:forecast_generated, ev})

    Ecto.Multi.insert(
      multi,
      :forecast,
      %Forecast{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: ev.org_id,
        currency: ev.currency,
        horizon_days: ev.horizon_days,
        predicted_inflow: ev.predicted_inflow,
        predicted_outflow: ev.predicted_outflow,
        predicted_gap: ev.predicted_gap,
        generated_at: ev.generated_at
      },
      on_conflict: :replace_all,
      conflict_target: [:org_id, :currency, :horizon_days]
    )
  end)
end
