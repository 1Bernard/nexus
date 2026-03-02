defmodule Nexus.ERP.StatementAdvancedGatewayTest do
  use Nexus.DataCase, async: false

  @moduletag :no_sandbox

  alias Nexus.ERP
  alias Nexus.ERP.Commands.UploadStatement
  alias Nexus.Treasury.Commands.ReconcileTransaction
  alias Nexus.ERP.Projections.{Statement, StatementLine}
  alias Nexus.App

  setup do
    org_id = Ecto.UUID.generate()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(StatementLine)
      Repo.delete_all(Statement)
      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM projection_versions")
    end)

    {:ok, org_id: org_id}
  end

  describe "Statement metrics and status" do
    test "initializes matched_count to 0 and detects overlap", %{org_id: org_id} do
      statement_id = Ecto.UUID.generate()
      content = "date,ref,amount,currency,narrative\n2024-01-01,REF001,100.00,EUR,Test narrative"

      # 1. Upload first statement
      cmd1 = %UploadStatement{
        statement_id: statement_id,
        org_id: org_id,
        filename: "bank_statement.csv",
        format: "csv",
        raw_content: content
      }

      assert :ok = App.dispatch(cmd1)

      # Project the event
      {:ok, [%{data: event, event_number: num}]} =
        Nexus.EventStore.read_stream_forward(statement_id)

      project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        statement = Repo.get(Statement, statement_id)
        assert statement.matched_count == 0
        assert statement.overlap_warning == false
      end)

      # 2. Upload duplicate filename
      statement_id2 = Ecto.UUID.generate()
      cmd2 = %{cmd1 | statement_id: statement_id2}

      assert :ok = App.dispatch(cmd2)

      # Project second event
      {:ok, [%{data: event2, event_number: num2}]} =
        Nexus.EventStore.read_stream_forward(statement_id2)

      project_event(
        event2,
        num2,
        "ERP.StatementProjector",
        Nexus.ERP.Projectors.StatementProjector
      )

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        statement2 = Repo.get(Statement, statement_id2)
        assert statement2.overlap_warning == true
      end)
    end

    test "increments matched_count on TransactionReconciled", %{org_id: org_id} do
      statement_id = Ecto.UUID.generate()
      content = "date,ref,amount,currency,narrative\n2024-01-01,REF001,100.00,EUR,Test narrative"

      cmd1 = %UploadStatement{
        statement_id: statement_id,
        org_id: org_id,
        filename: "recon_test.csv",
        format: "csv",
        raw_content: content
      }

      assert :ok = App.dispatch(cmd1)

      {:ok, [%{data: event, event_number: num}]} =
        Nexus.EventStore.read_stream_forward(statement_id)

      project_event(event, num, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

      # Get the generated line id
      [line] =
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          ERP.list_statement_lines(statement_id)
        end)

      # Reconcile the line
      recon_id = Ecto.UUID.generate()

      recon_cmd = %ReconcileTransaction{
        reconciliation_id: recon_id,
        org_id: org_id,
        invoice_id: Ecto.UUID.generate(),
        statement_id: statement_id,
        statement_line_id: line.id,
        amount: "100.00",
        currency: "EUR",
        actor_email: "test@example.com"
      }

      assert :ok = App.dispatch(recon_cmd)

      {:ok, [%{data: recon_event, event_number: recon_num}]} =
        Nexus.EventStore.read_stream_forward(recon_id)

      project_event(
        recon_event,
        recon_num,
        "Treasury.ReconciliationProjector",
        Nexus.Treasury.Projectors.ReconciliationProjector
      )

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        statement = Repo.get(Statement, statement_id)
        assert statement.matched_count == 1
      end)
    end
  end

  describe "Filtering and Search" do
    test "list_statements filters by filename and date", %{org_id: org_id} do
      # Create two statements
      s1_id = Ecto.UUID.generate()
      s2_id = Ecto.UUID.generate()
      content = "date,ref,amount,currency,narrative\n2024-01-01,REF,0,EUR,N"

      App.dispatch(%UploadStatement{
        statement_id: s1_id,
        org_id: org_id,
        filename: "alpha.csv",
        format: "csv",
        raw_content: content
      })

      {:ok, [%{data: e1, event_number: n1}]} = Nexus.EventStore.read_stream_forward(s1_id)
      project_event(e1, n1, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

      App.dispatch(%UploadStatement{
        statement_id: s2_id,
        org_id: org_id,
        filename: "beta.csv",
        format: "csv",
        raw_content: content
      })

      {:ok, [%{data: e2, event_number: n2}]} = Nexus.EventStore.read_stream_forward(s2_id)
      project_event(e2, n2, "ERP.StatementProjector", Nexus.ERP.Projectors.StatementProjector)

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        # Test filename search
        results = ERP.list_statements(org_id, "alpha")
        assert length(results) == 1
        assert hd(results).id == s1_id

        # Test date filter (prefix)
        date_prefix = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d")
        results_date = ERP.list_statements(org_id, "", date_prefix)
        assert length(results_date) >= 2
      end)
    end
  end

  # --- Helpers ---

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Ecto.Adapters.SQL.query!(Repo, "DELETE FROM projection_versions")

      projector_module.handle(event, metadata)
    end)
  end
end
