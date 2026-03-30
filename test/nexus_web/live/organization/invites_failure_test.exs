defmodule NexusWeb.Organization.InvitesFailureTest do
  @moduledoc """
  BDD integration test for the invitation flow failure states.
  """
  use Cabbage.Feature, async: false, file: "organization/invitation_failure.feature"
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :no_sandbox

  setup %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    {:ok, %{conn: conn}}
  end

  # --- Given ---

  defgiven ~r/navigate/, _vars, state do
    {:ok, page_live, _html} = live(state.conn, "/invites/bad-token-123")
    # Ensure full render of the failure state
    inner_html = render(page_live)
    {:ok, Map.merge(state, %{page_live: page_live, result_html: inner_html})}
  end

  # --- When ---

  # --- Then ---

  defthen ~r/^they should see "(?<text>[^"]+)"$/, %{text: text}, state do
    html = render(state.page_live)
    assert html =~ text
    {:ok, state}
  end
end
