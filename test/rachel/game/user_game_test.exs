defmodule Rachel.Game.UserGameTest do
  use Rachel.DataCase, async: true

  alias Rachel.Accounts
  alias Rachel.Game.UserGame

  describe "changeset/2" do
    setup do
      # Create test user
      {:ok, user} =
        Accounts.register_user(%{
          email: "test@example.com",
          username: "testuser",
          password: "testpassword123"
        })

      %{user_id: user.id}
    end

    test "valid changeset with all required fields", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: 0,
        final_rank: 1,
        turns_taken: 15
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset without optional fields", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: 2
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without user_id" do
      game_id = Ecto.UUID.generate()

      attrs = %{
        game_id: game_id,
        position: 0
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without game_id", %{user_id: user_id} do
      attrs = %{
        user_id: user_id,
        position: 0
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{game_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without position", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{position: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with negative position", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: -1
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{position: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "invalid changeset with zero final_rank", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: 0,
        final_rank: 0
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{final_rank: ["must be greater than or equal to 1"]} = errors_on(changeset)
    end

    test "invalid changeset with negative turns_taken", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: 0,
        turns_taken: -5
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      refute changeset.valid?
      assert %{turns_taken: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "defaults turns_taken to 0", %{user_id: user_id} do
      game_id = Ecto.UUID.generate()

      attrs = %{
        user_id: user_id,
        game_id: game_id,
        position: 0
      }

      changeset = UserGame.changeset(%UserGame{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :turns_taken) == 0
    end
  end
end
