defmodule Rachel.Integration.ProfileFlowTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Complete profile flow" do
    setup :register_and_log_in_user
    setup :create_test_avatars

    test "new user completes profile wizard", %{conn: conn, user: user} do
      # Start wizard
      {:ok, view, html} = live(conn, ~p"/profile/wizard")
      assert html =~ "Choose Your Avatar"

      # Select avatar (first one)
      view |> element("button[phx-value-avatar-id]", "😀") |> render_click()
      view |> element("button", "Next") |> render_click()

      # Fill personal info
      view
      |> form("#wizard-form",
        profile: %{
          display_name: "TestPlayer",
          tagline: "Ready to win!",
          bio: "I love card games"
        }
      )
      |> render_submit()

      # Complete wizard
      view |> element("button", "Complete Profile") |> render_click()

      # Verify profile updated
      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.profile_completed == true
      assert updated_user.display_name == "TestPlayer"
      assert updated_user.tagline == "Ready to win!"
      assert updated_user.bio == "I love card games"
      assert updated_user.avatar_id != nil
    end

    test "existing user updates profile settings", %{conn: conn, user: user} do
      # Go to settings
      {:ok, view, html} = live(conn, ~p"/settings")
      assert html =~ "Profile Settings"

      # Update profile
      view
      |> form("#profile-form",
        profile: %{
          display_name: "UpdatedName",
          tagline: "New motto"
        }
      )
      |> render_submit()

      # Verify update
      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.display_name == "UpdatedName"
      assert updated_user.tagline == "New motto"
    end

    test "moderation blocks inappropriate content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#profile-form",
          profile: %{
            tagline: "damn this game"
          }
        )
        |> render_submit()

      assert html =~ "contains inappropriate language"
    end
  end

  defp create_test_avatars(_context) do
    alias Rachel.Game.Avatar
    alias Rachel.Repo

    # Create a few test avatars for each category
    avatars = [
      %{name: "Smiling Face", category: "faces", character: "😀", display_order: 1},
      %{name: "Cool Sunglasses", category: "faces", character: "😎", display_order: 2},
      %{name: "Dog", category: "animals", character: "🐶", display_order: 3},
      %{name: "Cat", category: "animals", character: "🐱", display_order: 4},
      %{name: "Game Controller", category: "objects", character: "🎮", display_order: 5}
    ]

    Enum.each(avatars, fn avatar_attrs ->
      %Avatar{}
      |> Avatar.changeset(avatar_attrs)
      |> Repo.insert!()
    end)

    :ok
  end
end
