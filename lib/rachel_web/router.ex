defmodule RachelWeb.Router do
  use RachelWeb, :router

  import RachelWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RachelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :put_content_security_policy
  end

  defp put_content_security_policy(conn, _opts) do
    # Generate nonce for LiveView inline scripts/styles
    nonce = generate_csp_nonce()
    conn = Plug.Conn.assign(conn, :csp_nonce, nonce)

    # Get host info for WebSocket connections
    host = conn.host
    port = conn.port
    ws_url = if port in [80, 443], do: "wss://#{host}", else: "wss://#{host}:#{port}"

    Plug.Conn.put_resp_header(
      conn,
      "content-security-policy",
      "default-src 'self'; " <>
        "script-src 'self' 'nonce-#{nonce}'; " <>
        "style-src 'self' 'nonce-#{nonce}'; " <>
        "img-src 'self' data: https:; " <>
        "font-src 'self' data:; " <>
        "connect-src 'self' #{ws_url} ws://#{host}:#{port}; " <>
        "frame-ancestors 'none'; " <>
        "base-uri 'self'; " <>
        "form-action 'self'"
    )
  end

  defp generate_csp_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
  end

  pipeline :health do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :ensure_api_token
  end

  # Rate limiting pipelines
  pipeline :rate_limit_strict do
    plug RachelWeb.Plugs.RateLimit, limit: 5, period_ms: 60_000, by: :ip
  end

  pipeline :rate_limit_auth do
    plug RachelWeb.Plugs.RateLimit, limit: 10, period_ms: 60_000, by: :ip
  end

  pipeline :rate_limit_normal do
    plug RachelWeb.Plugs.RateLimit, limit: 100, period_ms: 60_000, by: :user
  end

  defp ensure_api_token(conn, _opts), do: RachelWeb.Plugs.ApiAuth.ensure_api_token(conn, [])

  # Health check endpoint (no authentication required)
  scope "/", RachelWeb do
    pipe_through :health

    get "/health", HealthController, :check
  end

  scope "/", RachelWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Game routes - require authentication to prevent abuse
  scope "/", RachelWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/lobby", LobbyLive
    live "/games/:id", GameLive
  end

  # API routes for mobile apps
  scope "/api", RachelWeb.API do
    pipe_through [:api, :rate_limit_auth]

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register

    scope "/" do
      pipe_through [:api_auth, :rate_limit_normal]

      get "/auth/me", AuthController, :me
      post "/auth/logout", AuthController, :logout

      get "/games", GameController, :index
      post "/games", GameController, :create
      get "/games/:id", GameController, :show
      post "/games/:id/join", GameController, :join
      post "/games/:id/play", GameController, :play_cards
      post "/games/:id/draw", GameController, :draw_cards
    end
  end

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

  ## Authentication routes

  scope "/", RachelWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", RachelWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", RachelWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
