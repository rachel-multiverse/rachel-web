defmodule Rachel.Leaderboard.RatingHistory do
  @moduledoc """
  Schema for tracking Elo rating changes over time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "rating_history" do
    belongs_to :user, Rachel.Accounts.User
    belongs_to :game, Rachel.Game.Games, type: :binary_id

    field :rating_before, :integer
    field :rating_after, :integer
    field :rating_change, :integer
    field :game_position, :integer
    field :opponents_count, :integer

    timestamps(updated_at: false)
  end

  @required_fields [:user_id, :rating_before, :rating_after, :rating_change]
  @optional_fields [:game_id, :game_position, :opponents_count]

  def changeset(rating_history, attrs) do
    rating_history
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:game_id)
  end
end
