defmodule NexusWeb.Identity.SessionController do
  @moduledoc """
  Handles session creation after a successful WebAuthn authentication challenge.
  Receives a signed Phoenix.Token from the biometric hook and sets the user session.
  """
  use NexusWeb, :controller

  def create(conn, %{"token" => token}) do
    case Phoenix.Token.verify(NexusWeb.Endpoint, "user auth", token, max_age: 60) do
      {:ok, user_id} ->
        user = Nexus.Repo.get(Nexus.Identity.Projections.User, user_id)
        session_id = Nexus.Schema.generate_uuidv7()

        Nexus.App.dispatch(%Nexus.Identity.Commands.StartSession{
          org_id: user.org_id,
          user_id: user.id,
          session_id: session_id,
          session_token: Base.url_encode64(:crypto.strong_rand_bytes(32)),
          user_agent: get_req_header(conn, "user-agent") |> List.first(),
          ip_address: conn.remote_ip |> :inet.ntoa() |> to_string(),
          started_at: DateTime.utc_now()
        })

        conn
        |> put_session(:user_id, user_id)
        |> put_session(:session_id, session_id)
        |> put_session(
          :live_socket_id,
          "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
        )
        |> configure_session(renew: true)
        |> redirect(to: "/dashboard")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid or expired authentication token.")
        |> redirect(to: "/")
    end
  end

  def dev_login(conn, _params) do
    import Ecto.Query

    admin =
      Nexus.Repo.one(
        from u in Nexus.Identity.Projections.User,
          where: fragment("? @> ?", u.role, ^["admin"]),
          limit: 1
      )

    if admin do
      session_id = Nexus.Schema.generate_uuidv7()

      Nexus.App.dispatch(%Nexus.Identity.Commands.StartSession{
        org_id: admin.org_id,
        user_id: admin.id,
        session_id: session_id,
        session_token: "dev-session-token",
        user_agent: get_req_header(conn, "user-agent") |> List.first(),
        ip_address: "127.0.0.1",
        started_at: DateTime.utc_now()
      })

      conn
      |> put_session(:user_id, admin.id)
      |> put_session(:session_id, session_id)
      |> put_session(
        :live_socket_id,
        "users_sessions:#{Base.url_encode64(:crypto.strong_rand_bytes(32))}"
      )
      |> configure_session(renew: true)
      |> redirect(to: "/admin/users")
    else
      conn
      |> put_flash(:error, "No admin user found in database.")
      |> redirect(to: "/")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
