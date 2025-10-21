defmodule RachelWeb.HealthControllerTest do
  use RachelWeb.ConnCase

  describe "GET /health" do
    test "returns 200 OK when all checks pass", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert response["version"]
      assert response["timestamp"]
      assert response["checks"]["database"]["status"] == "pass"
      assert response["checks"]["application"]["status"] == "pass"
    end

    test "returns valid JSON structure", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, 200)

      # Verify all required fields are present
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
      assert Map.has_key?(response, "version")
      assert Map.has_key?(response, "checks")

      # Verify checks structure
      assert Map.has_key?(response["checks"], "database")
      assert Map.has_key?(response["checks"], "application")
    end

    test "does not require authentication", %{conn: conn} do
      # Health check should work without any authentication
      conn = get(conn, ~p"/health")
      assert conn.status == 200
    end

    test "returns ISO8601 timestamp", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, 200)

      # Verify timestamp is valid ISO8601
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(response["timestamp"])
    end
  end
end
