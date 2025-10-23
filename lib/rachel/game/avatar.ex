defmodule Rachel.Game.Avatar do
  @moduledoc """
  Schema for user profile avatars.

  Pre-made emoji avatars organized by category for user selection.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "avatars" do
    field :name, :string
    field :category, :string
    field :character, :string
    field :display_order, :integer
  end

  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [:name, :category, :character, :display_order])
    |> validate_required([:name, :category, :character, :display_order])
    |> validate_inclusion(:category, ~w(faces animals objects cards food nature))
  end
end
