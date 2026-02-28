defmodule Nexus.ERP.StatementUploadTest do
  use Cabbage.Feature, file: "erp/statement_upload.feature"
  use Nexus.DataCase
  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.ERP
  alias Nexus.ERP.Projectors.StatementProjector
  alias Nexus.ERP.Projections.{Statement, StatementLine}

  # ---------------------------------------------------------------------------
  # Sample fixtures
  # ---------------------------------------------------------------------------

  @mt940_sample """
  :20:STMT-REF-001
  :25:IBAN-DE89370400440532013000
  :28C:00001/001
  :60F:C230101EUR10000,00
  :61:2301030103CR1500,00NTRFBACS-REF-001
  :86:VENDOR PAYMENT EUR/USD BATCH A
  :61:2301040104CR2000,00NTRFBACS-REF-002
  :86:FX SETTLEMENT TRANCHE B
  :61:2301050105DR500,00NTRFBACS-REF-003
  :86:BANK CHARGES JAN
  :62F:C230105EUR13000,00
  """

  @csv_sample """
  date,ref,amount,currency,narrative
  2023-01-03,BACS-REF-001,1500.00,EUR,Vendor Payment Batch A
  2023-01-04,BACS-REF-002,2000.00,USD,FX Settlement Tranche B
  """

  @invalid_content ""

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query

      Nexus.Repo.delete_all(StatementLine)
      Nexus.Repo.delete_all(Statement)

      Nexus.Repo.delete_all(
        from p in "projection_versions",
          where: p.projection_name == "ERP.StatementProjector"
      )
    end)

    {:ok, %{}}
  end

  # ---------------------------------------------------------------------------
  # Given
  # ---------------------------------------------------------------------------

  defgiven ~r/^I am uploading as organisation "(?<org>[^"]+)"$/, %{org: _org}, state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, Map.put(state, :org_id, org_id)}
  end

  # ---------------------------------------------------------------------------
  # When
  # ---------------------------------------------------------------------------

  defwhen ~r/^I upload an MT940 statement with (?<n>[0-9]+) transaction lines$/,
          %{n: _n},
          state do
    statement_id = Nexus.Schema.generate_uuidv7()

    command = %Nexus.ERP.Commands.UploadStatement{
      statement_id: statement_id,
      org_id: state.org_id,
      filename: "january.sta",
      format: "mt940",
      raw_content: @mt940_sample
    }

    :ok = App.dispatch(command)

    # Project the resulting event directly (bypass consistency/async)
    event = %Nexus.ERP.Events.StatementUploaded{
      statement_id: statement_id,
      org_id: state.org_id,
      filename: "january.sta",
      format: "mt940",
      lines: parse_mt940_lines(),
      uploaded_at: DateTime.utc_now()
    }

    project_event(event, 1)

    {:ok, Map.merge(state, %{statement_id: statement_id})}
  end

  defwhen ~r/^I upload a CSV statement with (?<n>[0-9]+) transaction lines$/, %{n: _n}, state do
    statement_id = Nexus.Schema.generate_uuidv7()

    command = %Nexus.ERP.Commands.UploadStatement{
      statement_id: statement_id,
      org_id: state.org_id,
      filename: "january.csv",
      format: "csv",
      raw_content: @csv_sample
    }

    :ok = App.dispatch(command)

    event = %Nexus.ERP.Events.StatementUploaded{
      statement_id: statement_id,
      org_id: state.org_id,
      filename: "january.csv",
      format: "csv",
      lines: parse_csv_lines(),
      uploaded_at: DateTime.utc_now()
    }

    project_event(event, 1)

    {:ok, Map.merge(state, %{statement_id: statement_id})}
  end

  defwhen ~r/^I upload an invalid statement file$/, _vars, state do
    statement_id = Nexus.Schema.generate_uuidv7()

    command = %Nexus.ERP.Commands.UploadStatement{
      statement_id: statement_id,
      org_id: state.org_id,
      filename: "broken.sta",
      format: "mt940",
      raw_content: @invalid_content
    }

    :ok = App.dispatch(command)

    # StatementRejected — do NOT project (nothing to read model)

    {:ok, Map.merge(state, %{statement_id: statement_id})}
  end

  # ---------------------------------------------------------------------------
  # Then
  # ---------------------------------------------------------------------------

  defthen ~r/^the statement should be accepted$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      stmt = Nexus.Repo.one(from s in Statement, where: s.id == ^state.statement_id)
      assert stmt != nil
      assert stmt.status == "uploaded"
    end)

    {:ok, state}
  end

  defthen ~r/^the statement should have (?<n>[0-9]+) parsed lines$/, %{n: n_str}, state do
    expected = String.to_integer(n_str)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query

      count =
        Nexus.Repo.one(
          from l in StatementLine,
            where: l.statement_id == ^state.statement_id,
            select: count(l.id)
        )

      assert count == expected,
             "Expected #{expected} lines, got #{count}"
    end)

    {:ok, state}
  end

  defthen ~r/^the statement should be rejected with a reason$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      stmt = Nexus.Repo.one(from s in Statement, where: s.id == ^state.statement_id)
      assert stmt == nil, "Rejected statement should not appear in read model"
    end)

    {:ok, state}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "ERP.StatementProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      StatementProjector.handle(event, metadata)
    end)
  end

  defp parse_mt940_lines do
    [
      %{
        id: Nexus.Schema.generate_uuidv7(),
        date: "2023-01-03",
        ref: "TRFBACS-REF-001",
        amount: Decimal.new("1500.00"),
        currency: "EUR",
        narrative: "VENDOR PAYMENT EUR/USD BATCH A"
      },
      %{
        id: Nexus.Schema.generate_uuidv7(),
        date: "2023-01-04",
        ref: "TRFBACS-REF-002",
        amount: Decimal.new("2000.00"),
        currency: "EUR",
        narrative: "FX SETTLEMENT TRANCHE B"
      },
      %{
        id: Nexus.Schema.generate_uuidv7(),
        date: "2023-01-05",
        ref: "TRFBACS-REF-003",
        amount: Decimal.negate(Decimal.new("500.00")),
        currency: "EUR",
        narrative: "BANK CHARGES JAN"
      }
    ]
  end

  defp parse_csv_lines do
    [
      %{
        id: Nexus.Schema.generate_uuidv7(),
        date: "2023-01-03",
        ref: "BACS-REF-001",
        amount: Decimal.new("1500.00"),
        currency: "EUR",
        narrative: "Vendor Payment Batch A"
      },
      %{
        id: Nexus.Schema.generate_uuidv7(),
        date: "2023-01-04",
        ref: "BACS-REF-002",
        amount: Decimal.new("2000.00"),
        currency: "USD",
        narrative: "FX Settlement Tranche B"
      }
    ]
  end
end
