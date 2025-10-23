defmodule RachelWeb.ProfileWizardLiveTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Rachel.GameFixtures

  describe "Profile wizard" do
    setup :register_and_log_in_user

    setup do
      seed_test_avatars()
      :ok
    end

    test "renders step 1 - avatar selection", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile/wizard")

      assert html =~ "Choose Your Avatar"
      assert html =~ "Step 1 of 3"
    end

    test "navigates through all steps", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/profile/wizard")

      # Step 1: Select avatar
      view
      |> element("button[phx-value-avatar-id]", "😀")
      |> render_click()

      html = view |> element("button", "Next") |> render_click()
      assert html =~ "Personal Information"
      assert html =~ "Step 2 of 3"

      # Step 2: Fill personal info
      html =
        view
        |> form("#wizard-form", profile: %{display_name: "TestUser", tagline: "Ready to play!"})
        |> render_submit()

      assert html =~ "Game Preferences"
      assert html =~ "Step 3 of 3"

      # Step 3: Complete wizard
      view |> element("button", "Complete Profile") |> render_click()

      # Should redirect to lobby
      assert_redirected(view, "/lobby")

      # Verify profile was actually completed
      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.profile_completed == true
      assert updated_user.display_name == "TestUser"
      assert updated_user.tagline == "Ready to play!"
    end
  end
end
