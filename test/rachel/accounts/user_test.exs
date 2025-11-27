defmodule Rachel.Accounts.UserTest do
  use Rachel.DataCase, async: true

  alias Rachel.Accounts.User

  describe "elo_changeset/2" do
    test "updates elo fields" do
      user = %User{}
      attrs = %{elo_rating: 1050, elo_games_played: 5, elo_tier: "silver"}
      changeset = User.elo_changeset(user, attrs)

      assert changeset.valid?
      assert get_change(changeset, :elo_rating) == 1050
      assert get_change(changeset, :elo_tier) == "silver"
    end

    test "validates elo_rating is non-negative" do
      changeset = User.elo_changeset(%User{}, %{elo_rating: -100})
      refute changeset.valid?
    end

    test "validates elo_tier is valid" do
      changeset = User.elo_changeset(%User{}, %{elo_tier: "invalid"})
      refute changeset.valid?
    end
  end
end
