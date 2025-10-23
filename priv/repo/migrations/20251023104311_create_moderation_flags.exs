defmodule Rachel.Repo.Migrations.CreateModerationFlags do
  use Ecto.Migration

  def change do
    create table(:moderation_flags, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :field_name, :string, null: false
      add :flagged_content, :text, null: false
      add :reason, :string, null: false
      add :status, :string, default: "pending", null: false
      add :reviewed_by, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:moderation_flags, [:user_id])
    create index(:moderation_flags, [:status])
    create index(:moderation_flags, [:reviewed_by])
  end
end
