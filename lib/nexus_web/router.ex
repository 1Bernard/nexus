defmodule NexusWeb.Router do
  use NexusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NexusWeb do
    pipe_through :browser
    get "/auth/login", SessionController, :create
    delete "/auth/logout", SessionController, :delete

    live_session :public,
      layout: false,
      on_mount: [{NexusWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/", Identity.BiometricLive
    end

    live_session :authenticated, on_mount: [{NexusWeb.UserAuth, :mount_current_user}] do
      live "/dashboard", DashboardLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", NexusWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:nexus, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/telemetry", metrics: NexusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      live "/design-system", NexusWeb.Dev.DesignSystemLive
    end
  end
end
