defmodule Rachel.GameFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Rachel.Game` context.
  """

  alias Rachel.Game.Avatar
  alias Rachel.Repo

  @doc """
  Generate an avatar.
  """
  def avatar_fixture(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Avatar",
      category: "faces",
      character: "😀",
      display_order: System.unique_integer([:positive])
    }

    attrs = Enum.into(attrs, default_attrs)

    %Avatar{}
    |> Avatar.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Seed a small set of test avatars for testing.
  """
  def seed_test_avatars do
    [
      %{name: "Smiling Face", category: "faces", character: "😀", display_order: 1},
      %{name: "Cool Sunglasses", category: "faces", character: "😎", display_order: 2},
      %{name: "Dog", category: "animals", character: "🐶", display_order: 3},
      %{name: "Cat", category: "animals", character: "🐱", display_order: 4},
      %{name: "Game Controller", category: "objects", character: "🎮", display_order: 5}
    ]
    |> Enum.map(fn attrs ->
      %Avatar{}
      |> Avatar.changeset(attrs)
      |> Repo.insert!()
    end)
  end
end
