defmodule NexusWeb.Payments.BulkPaymentLiveTest do
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo
  alias Uniq.UUID

  setup %{conn: conn} do
    user_id = UUID.uuid7()
    org_id = UUID.uuid7()

    user =
      %User{
        id: user_id,
        org_id: org_id,
        email: "payer@nexus.app",
        display_name: "Payer User",
        role: "admin",
        credential_id: "mock_cred",
        cose_key: "mock_key"
      }
      |> Repo.insert!()

    conn =
      conn
      |> Plug.Test.init_test_session(%{
        user_id: user_id,
        live_socket_id: "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
      })

    %{conn: conn, user: user, org_id: org_id}
  end

  describe "Bulk Payment Gateway" do
    test "mounts and shows the empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/payments")

      assert html =~ "Payment Gateway"
      assert html =~ "No bulk payments found"
    end

    test "handles CSV upload and staged review", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/payments")

      csv_content = "150.00,EUR,Vendor A,ACCOUNT-A-123\n500.50,GBP,Vendor B,ACCOUNT-B-456"

      # Simulate file selection
      batch =
        file_input(view, "#upload-form", :batch, [
          %{
            name: "batch.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      # Explicitly render upload and check that Analyze Batch button appears
      html = render_upload(batch, "batch.csv")
      assert html =~ "Analyze Batch"
      assert html =~ "batch.csv"

      # Submit the form to stage
      html = view |> form("#upload-form") |> render_submit()

      assert html =~ "Vendor A"
      assert html =~ "150.00"
      assert html =~ "Vendor B"
      assert html =~ "500.50"
    end

    test "handles 5-column CSV with optional invoice_id", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/payments")

      invoice_id = UUID.uuid7()
      csv_content = "250.00,EUR,Direct Vendor,ACC123,#{invoice_id}"

      batch =
        file_input(view, "#upload-form", :batch, [
          %{
            name: "batch.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(batch, "batch.csv")
      html = view |> form("#upload-form") |> render_submit()

      assert html =~ "Review Pending"
      assert html =~ "Direct Vendor"
      assert html =~ "250.00"
      # Just verify it parses and renders without crashing
    end

    test "authorizes a staged batch", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/payments")

      csv_content = "100.00,EUR,Target Vendor,IBAN12345678"

      batch =
        file_input(view, "#upload-form", :batch, [
          %{
            name: "batch.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(batch, "batch.csv")

      # Transition to staged
      html = view |> form("#upload-form") |> render_submit()
      assert html =~ "Review Pending"

      # Authorize
      html = view |> element("button", "Authorize & Instate") |> render_click()

      # Assert on synchronous side effects
      assert html =~ "Institutional Payment Batch Initiated"

      # The review modal should be gone
      refute html =~ "Review Pending"
      refute html =~ "Stage Payment Instructions"

      # Return to idle state
      assert html =~ "Drop your payment batch"
    end
  end
end
