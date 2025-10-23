defmodule Rachel.Game.AvatarLibraryTest do
  use Rachel.DataCase, async: true

  import Rachel.GameFixtures

  alias Rachel.Game.AvatarLibrary

  setup do
    # Seed some test avatars for each test
    avatars = seed_test_avatars()
    %{avatars: avatars}
  end

  describe "list_avatars/0" do
    test "returns all avatars ordered by display_order", %{avatars: _avatars} do
      avatars = AvatarLibrary.list_avatars()
      assert length(avatars) > 0
      assert Enum.all?(avatars, fn a -> a.character != nil end)

      # Verify ordering
      display_orders = Enum.map(avatars, & &1.display_order)
      assert display_orders == Enum.sort(display_orders)
    end
  end

  describe "list_avatars_by_category/1" do
    test "returns avatars filtered by category", %{avatars: _avatars} do
      avatars = AvatarLibrary.list_avatars_by_category("faces")
      assert length(avatars) > 0
      assert Enum.all?(avatars, fn a -> a.category == "faces" end)
    end
  end

  describe "get_avatar/1" do
    test "returns avatar by id", %{avatars: avatars} do
      first = List.first(avatars)
      avatar = AvatarLibrary.get_avatar(first.id)
      assert avatar.id == first.id
    end

    test "returns nil for invalid id" do
      assert nil == AvatarLibrary.get_avatar(99_999)
    end
  end

  describe "get_default_avatar/0" do
    test "returns first avatar as default", %{avatars: _avatars} do
      default = AvatarLibrary.get_default_avatar()
      assert default != nil
      assert default.id != nil
      assert default.display_order == 1
    end
  end
end
