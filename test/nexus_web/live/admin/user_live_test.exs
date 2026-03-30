defmodule NexusWeb.Admin.UserLiveTest do
  @moduledoc """
  Elite BDD tests for User Management UI.
  """
  use Cabbage.Feature, file: "organization/user_management_ui.feature"
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo
  alias Uniq.UUID

  @moduletag :no_sandbox

  setup %{conn: conn} do
    unboxed_run(fn ->
      Repo.delete_all(User)
    end)

    # Create an admin user directly in the database for the test
    admin_id = UUID.uuid7()
    org_id = UUID.uuid7()

    admin =
      unboxed_run(fn ->
        %User{
          id: admin_id,
          org_id: org_id,
          email: "test_admin@nexus.app",
          display_name: "Test Admin",
          roles: ["admin"],
          credential_id: "mock_cred",
          cose_key: "mock_key"
        }
        |> Repo.insert!()
      end)

    # Mock the session exactly as SessionController does
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        user_id: admin_id,
        live_socket_id: "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
      })

    {:ok, %{conn: conn, admin: admin, org_id: org_id}}
  end

  defgiven "an organization admin is logged in", _args, %{conn: conn} do
    # Logged in via setup session
    {:ok, %{conn: conn}}
  end

  defgiven ~r/^a user "(?<name>[^"]+)" exists with role "(?<role>[^"]+)"$/,
           %{name: name, role: role},
           %{org_id: org_id} do
    user_id = UUID.uuid7()

    unboxed_run(fn ->
      %User{
        id: user_id,
        org_id: org_id,
        email: "#{String.downcase(String.replace(name, " ", "_"))}@nexus.app",
        display_name: name,
        roles: [role],
        credential_id: "mock_cred_#{user_id}",
        cose_key: "mock_key_#{user_id}"
      }
      |> Repo.insert!()
    end)

    {:ok, %{user_id: user_id}}
  end

  defwhen ~r/^they navigate to the "(?<page>[^"]+)" page$/, %{page: "Users"}, %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/admin/users")
    {:ok, %{page_live: page_live}}
  end

  defwhen "they open the \"Invite User\" modal", _args, %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/admin/users")
    html = page_live |> element("button", "Invite User") |> render_click()
    {:ok, %{page_live: page_live, modal_html: html}}
  end

  defwhen ~r/^they select the "(?<role>[^"]+)" role for the invitation$/,
          %{role: role},
          %{page_live: page_live} do
    html =
      page_live
      |> form("form[phx-submit=\"confirm-generate-invite\"]", %{
        "role" => role,
        "display_name" => "Invitation Test",
        "email" => "invite@nexus.app"
      })
      |> render_submit()

    {:ok, %{result_html: html}}
  end

  defwhen ~r/^they filter the user list by "(?<role>[^"]+)"$/,
          %{role: "trader"},
          %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/admin/users")
    # Click on Trader filter
    html = page_live |> element("button", "Traders") |> render_click()
    {:ok, %{page_live: page_live, filtered_html: html}}
  end

  defthen ~r/^they should see the user "(?<name>[^"]+)" in the team list$/,
          %{name: name},
          %{page_live: page_live} do
    html = render(page_live)
    assert html =~ name
    :ok
  end

  # Special case for filter result
  defthen ~r/^they should see the filtered user "(?<name>[^"]+)" in the list$/,
          %{name: name},
          %{filtered_html: html} do
    assert html =~ name
    :ok
  end

  defthen "the \"Invite User\" button should be visible", _args, %{page_live: page_live} do
    assert has_element?(page_live, "button", "Invite User")
    :ok
  end

  defthen "a \"Single-Use Secure Link\" should be generated", _args, %{result_html: html} do
    assert html =~ "Single-Use Secure Link"
    assert html =~ "/auth/invite/"
    :ok
  end

  defthen "they should not see the admin user", _args, %{filtered_html: html} do
    refute html =~ "test_admin@nexus.app"
    :ok
  end
end
