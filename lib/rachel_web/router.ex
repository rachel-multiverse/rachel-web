defmodule RachelWeb.Router do
  use RachelWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RachelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_content_security_policy
  end

  defp put_content_security_policy(conn, _opts) do
    Plug.Conn.put_resp_header(
      conn,
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:;"
    )
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RachelWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Game routes
    live "/games/:id", GameLive
    live "/lobby", LobbyLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", RachelWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rachel, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RachelWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
