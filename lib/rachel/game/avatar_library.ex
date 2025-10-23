defmodule Rachel.Game.AvatarLibrary do
  @moduledoc """
  Manages the avatar library - pre-made emoji avatars users can choose from.
  """

  import Ecto.Query
  alias Rachel.Game.Avatar
  alias Rachel.Repo

  @doc """
  Lists all avatars ordered by display_order.
  """
  def list_avatars do
    Avatar
    |> order_by([a], a.display_order)
    |> Repo.all()
  end

  @doc """
  Lists avatars filtered by category.
  """
  def list_avatars_by_category(category) do
    Avatar
    |> where([a], a.category == ^category)
    |> order_by([a], a.display_order)
    |> Repo.all()
  end

  @doc """
  Gets a single avatar by id.
  """
  def get_avatar(id) do
    Repo.get(Avatar, id)
  end

  @doc """
  Gets the default avatar (first one in the library).
  """
  def get_default_avatar do
    Avatar
    |> order_by([a], a.display_order)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Lists all available categories.
  """
  def list_categories do
    Avatar
    |> select([a], a.category)
    |> distinct(true)
    |> order_by([a], a.category)
    |> Repo.all()
  end
end
