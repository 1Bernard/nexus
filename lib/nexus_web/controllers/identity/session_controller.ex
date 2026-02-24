defmodule NexusWeb.Identity.SessionController do
  use NexusWeb, :controller

  def create(conn, %{"token" => token}) do
    case Phoenix.Token.verify(NexusWeb.Endpoint, "user auth", token, max_age: 60) do
      {:ok, user_id} ->
        conn
        |> put_session(:user_id, user_id)
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

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
