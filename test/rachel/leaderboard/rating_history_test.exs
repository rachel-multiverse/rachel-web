defmodule Rachel.Leaderboard.RatingHistoryTest do
  use Rachel.DataCase, async: true

  alias Rachel.Leaderboard.RatingHistory

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      user = insert_user()

      attrs = %{
        user_id: user.id,
        rating_before: 1000,
        rating_after: 1015,
        rating_change: 15,
        game_position: 1,
        opponents_count: 3
      }

      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      assert changeset.valid?
    end

    test "invalid without user_id" do
      attrs = %{rating_before: 1000, rating_after: 1015, rating_change: 15}
      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "invalid without rating fields" do
      user = insert_user()
      attrs = %{user_id: user.id}
      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      refute changeset.valid?
    end
  end

  defp insert_user do
    {:ok, user} =
      %Rachel.Accounts.User{}
      |> Rachel.Accounts.User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Rachel.Repo.insert()
    user
  end
end
