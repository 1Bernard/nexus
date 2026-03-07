defmodule NexusWeb.Marketing.PageController do
  @moduledoc """
  Handles the application root route, rendering the home template.
  """
  use NexusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
