defmodule RachelWeb.LegalControllerTest do
  use RachelWeb.ConnCase

  describe "GET /privacy" do
    test "renders privacy policy page", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      response = html_response(conn, 200)

      assert response =~ "Privacy Policy"
      assert response =~ "information"
    end

    test "has correct page title", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      assert html_response(conn, 200) =~ "Privacy Policy"
    end
  end

  describe "GET /terms" do
    test "renders terms of service page", %{conn: conn} do
      conn = get(conn, ~p"/terms")
      response = html_response(conn, 200)

      assert response =~ "Terms of Service"
      assert response =~ "agreement"
    end

    test "has correct page title", %{conn: conn} do
      conn = get(conn, ~p"/terms")
      assert html_response(conn, 200) =~ "Terms of Service"
    end
  end
end
