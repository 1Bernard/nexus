defmodule NexusWeb.Organization.InvitesLiveTest do
  use Cabbage.Feature, async: false, file: "organization/invitation_flow.feature"
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Nexus.Schema

  @moduletag :no_sandbox

  setup %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    {:ok, %{conn: conn}}
  end

  # --- Given ---

  defgiven ~r/^an invalid invitation "(?<token>[^"]+)"$/, %{token: token}, %{conn: conn} do
    {:ok, %{conn: conn, token: token}}
  end

  defgiven "a valid invitation exists for \"trader\" role", _args, %{conn: conn} do
    org_id = Schema.generate_uuidv7()
    invited_by = Schema.generate_uuidv7()

    token =
      Phoenix.Token.sign(NexusWeb.Endpoint, "user_invitation", %{
        org_id: org_id,
        role: "trader",
        invited_by: invited_by
      })

    {:ok, %{conn: conn, token: token, org_id: org_id}}
  end

  # --- When ---

  defwhen "they navigate to it", _args, state do
    {:ok, page_live, html} = live(state.conn, "/invites/#{state.token}")
    {:ok, %{page_live: page_live, result_html: html}}
  end

  defwhen "they use a valid invitation", _args, state do
    {:ok, page_live, html} = live(state.conn, "/invites/#{state.token}")
    {:ok, %{page_live: page_live, result_html: html}}
  end

  defwhen "they submit the acceptance form with values:", %{table: table}, state do
    [row] = table
    display_name = row[:display_name]
    email = row[:email]

    result =
      state.page_live
      |> form("#registration-form", %{
        "registration[display_name]" => display_name,
        "registration[email]" => email
      })
      |> render_submit()

    {:ok, %{result_html: result}}
  end

  # --- Then ---

  defthen ~r/^they should see "(?<text>[^"]+)"$/, %{text: text}, state do
    html = state.result_html
    case html do
      h when is_binary(h) -> assert h =~ text
      _ -> flunk("Expected HTML string, got: #{inspect(html)}")
    end
    :ok
  end

  defthen ~r/^they should see "(?<text>[^"]+)" in the role description$/,
          %{text: text},
          state do
    html = state.result_html
    case html do
      h when is_binary(h) -> assert h =~ text
      _ -> flunk("Expected HTML string, got: #{inspect(html)}")
    end
    :ok
  end

  defthen "they should be redirected to the identity gate", _args, state do
    case state.result_html do
      {:error, {:live_redirect, %{to: path}}} ->
        assert path =~ "/auth/gate"
        assert path =~ "intent=register"
        {:ok, %{redirect_path: path}}
      other ->
        flunk("Expected live redirect, got: #{inspect(other)}")
    end
  end

  defthen "the gate token should contain the correct invitation data",
          _args,
          state do
    path = state.redirect_path
    [_, token_part] = String.split(path, "token=")
    token = token_part |> String.split("&") |> List.first()

    assert {:ok, payload} =
             Phoenix.Token.verify(NexusWeb.Endpoint, "biometric_registration", token)

    assert payload.org_id == state.org_id
    assert payload.display_name == "Test Invited User"
    assert payload.email == "test.invitee@global.com"
    :ok
  end
end
