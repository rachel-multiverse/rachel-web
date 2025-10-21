defmodule RachelWeb.Plugs.RateLimitTest do
  use RachelWeb.ConnCase

  describe "rate limiting" do
    @tag :capture_log
    test "rate limiter sets headers on requests" do
      conn = build_conn()

      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "test@example.com",
          password: "password123"
        })

      # Should have rate limit headers (even if request fails auth)
      assert get_resp_header(conn, "x-ratelimit-limit") != []
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
    end

    @tag :capture_log
    test "rate limiter is active on API endpoints" do
      # Just verify the rate limiter plug is working by checking headers
      # We won't test exhaustion since that would interfere with other tests

      conn = build_conn()

      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "test@example.com",
          password: "password123"
        })

      # Verify rate limiting headers are present
      assert ["10"] = get_resp_header(conn, "x-ratelimit-limit")
      remaining = get_resp_header(conn, "x-ratelimit-remaining")
      assert remaining != []
      # Remaining should be a number
      [remaining_str] = remaining
      {remaining_int, _} = Integer.parse(remaining_str)
      assert remaining_int >= 0 and remaining_int <= 10
    end

    @tag :capture_log
    test "rate limiter allows requests under limit" do
      # Make just a few requests
      results =
        Enum.map(1..3, fn i ->
          conn = build_conn()

          conn =
            post(conn, ~p"/api/auth/login", %{
              email: "test#{i}@example.com",
              password: "password123"
            })

          conn.status
        end)

      # All should be allowed (not 429), even if they fail auth
      Enum.each(results, fn status ->
        refute status == 429, "Should not be rate limited for #{status}"
      end)
    end
  end
end
