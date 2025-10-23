defmodule Rachel.Repo.Migrations.CreateAvatars do
  use Ecto.Migration

  def change do
    create table(:avatars) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :character, :string, null: false
      add :display_order, :integer, null: false, default: 0
    end

    create index(:avatars, [:category])
    create index(:avatars, [:display_order])
  end
end
