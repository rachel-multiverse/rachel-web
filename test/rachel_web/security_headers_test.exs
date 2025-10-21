defmodule RachelWeb.SecurityHeadersTest do
  use RachelWeb.ConnCase

  describe "security headers on all responses" do
    test "endpoint sets X-Frame-Options header", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "endpoint sets X-Content-Type-Options header", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "endpoint sets Referrer-Policy header", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "endpoint sets Permissions-Policy header", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_resp_header(conn, "permissions-policy") == [
               "geolocation=(), microphone=(), camera=()"
             ]
    end

    test "endpoint sets HSTS header in production only", %{conn: conn} do
      # In test environment, HSTS should not be set
      conn = get(conn, ~p"/")
      assert get_resp_header(conn, "strict-transport-security") == []
    end

    test "router sets Content-Security-Policy with nonce", %{conn: conn} do
      conn = get(conn, ~p"/")
      [csp] = get_resp_header(conn, "content-security-policy")

      # Verify CSP contains expected directives
      assert csp =~ "default-src 'self'"
      assert csp =~ "script-src 'self' 'nonce-"
      assert csp =~ "style-src 'self' 'nonce-"
      assert csp =~ "img-src 'self' data: https:"
      assert csp =~ "font-src 'self' data:"
      assert csp =~ "connect-src 'self'"
      assert csp =~ "frame-ancestors 'none'"
      assert csp =~ "base-uri 'self'"
      assert csp =~ "form-action 'self'"
    end

    test "CSP nonce is available in conn assigns", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert conn.assigns[:csp_nonce]
      assert is_binary(conn.assigns.csp_nonce)
      # Nonce should be base64 encoded (no padding)
      assert String.length(conn.assigns.csp_nonce) > 0
      assert String.match?(conn.assigns.csp_nonce, ~r/^[A-Za-z0-9+\/]+$/)
    end

    test "CSP nonce in header matches assigned nonce", %{conn: conn} do
      conn = get(conn, ~p"/")
      nonce = conn.assigns.csp_nonce
      [csp] = get_resp_header(conn, "content-security-policy")

      assert csp =~ "script-src 'self' 'nonce-#{nonce}'"
      assert csp =~ "style-src 'self' 'nonce-#{nonce}'"
    end

    test "security headers are present on API routes", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "password123"
      })

      # All security headers should be present
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
      assert get_resp_header(conn, "permissions-policy") == [
               "geolocation=(), microphone=(), camera=()"
             ]
    end

    test "security headers are present on LiveView routes", %{conn: conn} do
      conn = get(conn, ~p"/lobby")

      # All security headers should be present
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
      assert get_resp_header(conn, "permissions-policy") == [
               "geolocation=(), microphone=(), camera=()"
             ]
    end
  end
end
