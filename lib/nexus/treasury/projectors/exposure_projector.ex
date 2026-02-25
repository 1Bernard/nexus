defmodule Nexus.Treasury.Projectors.ExposureProjector do
  @moduledoc """
  Listens for ExposureCalculated events and writes the latest FX exposure
  snapshot per subsidiary and currency to the treasury_exposure_snapshots table.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ExposureProjector",
    consistency: :strong

  # Explicitly marked overridable so the test-env override below does not
  # produce a compile warning about shadowing the macro-defined clause.
  defoverridable update_projection: 3

  require Logger

  alias Nexus.Treasury.Events.ExposureCalculated
  alias Nexus.Treasury.Projections.ExposureSnapshot

  project(%ExposureCalculated{} = event, _metadata, fn multi ->
    id = "#{event.subsidiary}-#{event.currency}"

    exposure_amount =
      case event.exposure_amount do
        %Decimal{} = d -> d
        s when is_binary(s) -> Decimal.new(s)
        n when is_number(n) -> Decimal.new(n)
      end

    calculated_at =
      case event.timestamp do
        %DateTime{} = dt -> dt
        s when is_binary(s) -> elem(DateTime.from_iso8601(s), 1)
      end

    Ecto.Multi.insert(
      multi,
      :exposure_snapshot,
      %ExposureSnapshot{
        id: id,
        org_id: event.org_id,
        subsidiary: event.subsidiary,
        currency: event.currency,
        exposure_amount: exposure_amount,
        calculated_at: calculated_at
      },
      on_conflict: :replace_all,
      conflict_target: [:id]
    )
  end)

  if Mix.env() == :test do
    # In test, the Ecto Sandbox blocks Repo.transaction from the projector process
    # (even with Sandbox.allow). Override the repo transaction to run inside
    # Sandbox.unboxed_run, giving us a real connection that can actually commit.
    def update_projection(event, metadata, multi_fn) do
      import Ecto.Query, only: [from: 2]

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
        projection_name = Map.fetch!(metadata, :handler_name)
        event_number = Map.fetch!(metadata, :event_number)

        projection_version = %__MODULE__.ProjectionVersion{
          projection_name: projection_name,
          last_seen_event_number: event_number
        }

        update_projection_version_query =
          from(pv in __MODULE__.ProjectionVersion,
            where:
              pv.projection_name == ^projection_name and
                pv.last_seen_event_number < ^event_number,
            update: [set: [last_seen_event_number: ^event_number]]
          )

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.run(:track_projection_version, fn repo, _changes ->
            try do
              repo.insert(projection_version,
                on_conflict: update_projection_version_query,
                conflict_target: [:projection_name]
              )
            rescue
              _e in Ecto.StaleEntryError -> {:error, :already_seen_event}
              e -> reraise e, __STACKTRACE__
            end
          end)

        with %Ecto.Multi{} = multi <- apply(multi_fn, [multi]),
             {:ok, changes} <- Nexus.Repo.transaction(multi) do
          after_update(event, metadata, changes)
        else
          {:error, :track_projection_version, :already_seen_event, _} -> :ok
          {:error, _stage, err, _changes} -> {:error, err}
          {:error, _err} = reply -> reply
        end
      end)
    end
  end

  def after_update(event, _metadata, _changes) do
    require Logger
    Logger.debug("[ExposureProjector] committed #{event.subsidiary}-#{event.currency}")
    :ok
  end
end
