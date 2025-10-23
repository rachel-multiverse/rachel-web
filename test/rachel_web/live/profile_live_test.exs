defmodule RachelWeb.ProfileLiveTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Profile settings page" do
    setup :register_and_log_in_user

    test "renders profile settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Profile Settings"
      assert html =~ "Choose Avatar"
      assert html =~ "Display Name"
    end

    test "updates display name", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      assert view
             |> form("#profile-form", profile: %{display_name: "New Name"})
             |> render_submit()

      assert_patch(view, ~p"/settings")

      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.display_name == "New Name"
    end

    test "shows validation errors for invalid display name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#profile-form", profile: %{display_name: "ab"})
        |> render_submit()

      assert html =~ "should be at least 3 character"
    end
  end
end
