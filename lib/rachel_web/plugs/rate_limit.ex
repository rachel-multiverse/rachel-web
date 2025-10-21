defmodule RachelWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer to prevent abuse and brute force attacks.

  ## Usage

      # In router.ex
      pipeline :rate_limit_strict do
        plug RachelWeb.Plugs.RateLimit, limit: 5, period_ms: 60_000, by: :ip
      end

      scope "/api" do
        pipe_through [:api, :rate_limit_strict]
        post "/auth/login", AuthController, :login
      end

  ## Options

    * `:limit` - Maximum number of requests allowed (default: 100)
    * `:period_ms` - Time window in milliseconds (default: 60_000 = 1 minute)
    * `:by` - Rate limit by `:ip`, `:user`, or `:session` (default: `:ip`)

  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    identifier = get_identifier(conn, opts)
    limit = Keyword.get(opts, :limit, 100)
    period_ms = Keyword.get(opts, :period_ms, 60_000)
    bucket = "rate_limit:#{conn.request_path}:#{identifier}"

    case Hammer.check_rate(bucket, period_ms, limit) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(limit - count))
        |> put_resp_header("x-ratelimit-reset", to_string(period_ms))

      {:deny, _limit} ->
        Logger.warning("Rate limit exceeded for #{identifier} on #{conn.request_path}")

        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(div(period_ms, 1000)))
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> json(%{error: "Rate limit exceeded. Please try again later."})
        |> halt()
    end
  end

  defp get_identifier(conn, opts) do
    case Keyword.get(opts, :by, :ip) do
      :ip ->
        ip = to_string(:inet_parse.ntoa(conn.remote_ip))
        ip

      :user ->
        current_user = Map.get(conn.assigns, :current_user)
        user_id = if current_user, do: current_user.id, else: "anonymous"
        "user:#{user_id}"

      :session ->
        session_id = get_session(conn, :user_token) || "anonymous"
        "session:#{session_id}"
    end
  end
end
