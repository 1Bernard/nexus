defmodule NexusWeb.Admin.UserLiveTest do
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo
  alias Uniq.UUID

  setup %{conn: conn} do
    # Create an admin user directly in the database for the test
    admin_id = UUID.uuid7()
    org_id = UUID.uuid7()

    admin =
      %User{
        id: admin_id,
        org_id: org_id,
        email: "test_admin@nexus.app",
        display_name: "Test Admin",
        role: "admin",
        credential_id: "mock_cred",
        cose_key: "mock_key"
      }
      |> Repo.insert!()

    # Mock the session exactly as SessionController does
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        user_id: admin_id,
        live_socket_id: "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
      })

    %{conn: conn, admin: admin, org_id: org_id}
  end

  describe "User Management LiveView" do
    test "mounts correctly and renders the Institutional DataGrid", %{conn: conn} do
      {:ok, _page_live, html} = live(conn, "/admin/users")

      assert html =~ "User Management"
      assert html =~ "Manage your team"
      assert html =~ "Test Admin"
      assert html =~ "test_admin@nexus.app"
      assert html =~ "Invite User"

      # Presence check (Active Sessions sidebar should show the admin)
      assert html =~ "Active Sessions"
      assert html =~ "1 LIVE"
    end

    test "handles invitation link generation via modal", %{conn: conn} do
      {:ok, page_live, _html} = live(conn, "/admin/users")

      # 1. Open the modal
      html = page_live |> element("button", "Invite User") |> render_click()
      assert html =~ "Generate Invitation"
      assert html =~ "Assigned Role"
      assert html =~ "admin"
      assert html =~ "trader"

      # 2. Select a role and submit form
      html =
        page_live
        |> form("form[phx-submit=\"confirm-generate-invite\"]", %{"role" => "trader"})
        |> render_submit()

      # 3. Verify modal state changed to success
      assert html =~ "Single-Use Secure Link"
      assert html =~ "/auth/invite/"
      assert html =~ "This link will expire in 24 hours. Once used, it cannot be reused."
    end

    test "filters users by role correctly", %{conn: conn, org_id: org_id} do
      # Insert a trader user
      trader_id = UUID.uuid7()

      %User{
        id: trader_id,
        org_id: org_id,
        email: "trader_joe@nexus.app",
        display_name: "Trader Joe",
        role: "trader",
        credential_id: "mock_cred_2",
        cose_key: "mock_key_2"
      }
      |> Repo.insert!()

      {:ok, page_live, html} = live(conn, "/admin/users")
      assert html =~ "Test Admin"
      assert html =~ "Trader Joe"

      # Click on Trader filter
      html = page_live |> element("button", "Traders") |> render_click()

      # Verify only trader is shown
      assert html =~ "Trader Joe"
      refute html =~ "test_admin@nexus.app"
    end
  end
end
