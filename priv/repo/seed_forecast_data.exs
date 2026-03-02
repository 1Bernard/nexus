Mix.Task.run("app.config")
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Nexus.Repo.start_link()

import Ecto.Query

# Ensure we get a valid string representation, not a null binary if the query fails
org_id_str = Nexus.Repo.one!(from(u in "users", limit: 1, select: type(u.org_id, :string)))

if org_id_str do
  org_id_bin = Ecto.UUID.dump!(org_id_str)

  # Clean old data
  Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM erp_statement_lines WHERE narrative LIKE 'FAKE-%'")
  Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM erp_statements WHERE filename = 'FAKE_HISTORICAL_60_DAYS.csv'")

  statement_id_raw = Ecto.UUID.generate()
  statement_id = Ecto.UUID.dump!(statement_id_raw)
  now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  Nexus.Repo.insert_all("erp_statements", [
    %{
      id: statement_id,
      org_id: org_id_bin,
      filename: "FAKE_HISTORICAL_60_DAYS.csv",
      format: "csv",
      uploaded_at: now,
      status: "processed",
      matched_count: 60,
      line_count: 60,
      created_at: now,
      updated_at: now
    }
  ])

  today = Date.utc_today()

  lines =
    for i <- 60..1//-1 do
      amount = Float.round(1000.0 + :rand.uniform(500) - (60 - i) * 10, 2)

      %{
        id: Ecto.UUID.dump!(Ecto.UUID.generate()),
        org_id: org_id_bin,
        statement_id: statement_id,
        narrative: "FAKE-#{i}",
        amount: Decimal.from_float(amount),
        currency: "EUR",
        date: Date.add(today, -i) |> Date.to_string(),
        status: "processed",
        error_message: nil,
        created_at: now,
        updated_at: now
      }
    end

  Nexus.Repo.insert_all("erp_statement_lines", lines)
  IO.puts("✅ Seeded 60 days of historical data for ForecastEngine.")
else
  IO.puts("❌ No users found in database.")
end
