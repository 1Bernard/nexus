defmodule NexusWeb.Organization.InvitesLiveTest do
  use NexusWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @endpoint NexusWeb.Endpoint

  describe "InvitesLive" do
    test "renders invalid link error when token is bad", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/invites/bad-token-123")

      assert html =~ "Invalid or Expired Link"
      assert html =~ "This invitation link is no longer valid"
    end

    test "renders accept invitation form when token is valid", %{conn: conn} do
      org_id = Nexus.Schema.generate_uuidv7()

      # Generate a valid token
      token =
        Phoenix.Token.sign(
          @endpoint,
          "user_invitation",
          %{
            org_id: org_id,
            role: "trader",
            invited_by: Nexus.Schema.generate_uuidv7()
          }
        )

      {:ok, view, html} = live(conn, ~p"/invites/#{token}")

      assert html =~ "Accept Invitation"
      assert html =~ "trader"
      assert html =~ "Full Name"
      assert html =~ "Email Address"

      # Test form submission
      # Since it pushes navigation to /auth/gate with a new token, we assert the redirect
      view
      |> form("form", %{
        "display_name" => "Test Invited User",
        "email" => "test.invitee@global.com"
      })
      |> render_submit()

      {path, flash} = assert_redirect(view)

      # Verify the redirect URL contains the intent and token
      assert path =~ "/auth/gate?intent=register&token="

      # Extract the new token and verify it holds the expected payload
      [_, intent_token] = String.split(path, "token=")

      assert {:ok, payload} =
               Phoenix.Token.verify(@endpoint, "biometric_registration", intent_token,
                 max_age: 1800
               )

      assert payload.org_id == org_id
      assert payload.role == "trader"
      assert payload.email == "test.invitee@global.com"
      assert payload.display_name == "Test Invited User"
    end
  end
end
