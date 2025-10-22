defmodule Rachel.Game.UserGame do
  @moduledoc """
  Join table schema for tracking user participation in games.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "user_games" do
    belongs_to :user, Rachel.Accounts.User
    belongs_to :game, Rachel.Game.Games, type: :binary_id
    field :position, :integer
    field :final_rank, :integer
    field :turns_taken, :integer, default: 0

    timestamps()
  end

  @doc """
  Changeset for creating a user_game record.
  """
  def changeset(user_game, attrs) do
    user_game
    |> cast(attrs, [:user_id, :game_id, :position, :final_rank, :turns_taken])
    |> validate_required([:user_id, :game_id, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_number(:final_rank, greater_than_or_equal_to: 1)
    |> validate_number(:turns_taken, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :game_id])
  end
end
