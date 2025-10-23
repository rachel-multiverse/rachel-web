defmodule Rachel.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tagline, :string
      add :bio, :text
      add :avatar_id, references(:avatars, on_delete: :nilify_all)
      add :profile_completed, :boolean, default: false, null: false
    end

    create index(:users, [:avatar_id])
    create index(:users, [:profile_completed])
  end
end
