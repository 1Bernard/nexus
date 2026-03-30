defmodule NexusWeb.Payments.BulkPaymentGatewayTest do
  @moduledoc """
  Elite BDD tests for Bulk Payment Gateway.
  """
  use Cabbage.Feature, async: false, file: "payments/bulk_payment_gateway.feature"
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo
  alias Uniq.UUID

  @moduletag :no_sandbox

  setup %{conn: conn} do
    # Clear existing users to avoid unique constraint violations in :no_sandbox
    unboxed_run(fn ->
      Repo.delete_all(User)
    end)

    admin_id = UUID.uuid7()
    org_id = UUID.uuid7()

    admin =
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

    conn =
      conn
      |> Plug.Test.init_test_session(%{
        user_id: admin_id,
        live_socket_id: "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
      })

    {:ok, %{conn: conn, admin: admin, org_id: org_id}}
  end

  # --- Given ---

  defgiven "an organization admin is logged in", _args, %{conn: conn} do
    {:ok, %{conn: conn}}
  end

  # --- When ---

  defwhen "they navigate to the payment gateway", _args, %{conn: conn} do
    {:ok, page_live, _html} = live(conn, "/payments")
    {:ok, %{page_live: page_live}}
  end

  defwhen ~r/^they upload a CSV batch with content:$/, %{doc_string: content}, %{page_live: page_live} do
    # Simulate file selection
    batch =
      file_input(page_live, "#upload-form", :batch, [
        %{
          name: "batch.csv",
          content: content,
          type: "text/csv"
        }
      ])

    # Transition to staged view
    render_upload(batch, "batch.csv")
    html = page_live |> form("#upload-form") |> render_submit()

    {:ok, %{page_live: page_live, result_html: html}}
  end

  defwhen "they authorize and instate the batch", _args, %{page_live: page_live} do
    html = page_live |> element("button", "Authorize & Instate") |> render_click()
    {:ok, %{result_html: html}}
  end

  # --- Then ---

  defthen ~r/^they should see "(?<vendor>[^"]+)" for "(?<amount>[^"]+)"$/,
          %{vendor: vendor, amount: amount},
          %{result_html: html} do
    assert html =~ vendor
    assert html =~ amount
    :ok
  end

  defthen ~r/^they should see "(?<text>[^"]+)"$/, %{text: text}, %{result_html: html} do
    assert html =~ text
    :ok
  end

  defthen "the review modal should be closed", _args, %{result_html: html} do
    refute html =~ "Review Pending"
    refute html =~ "Stage Payment Instructions"
    :ok
  end
end
