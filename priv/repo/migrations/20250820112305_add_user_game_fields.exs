defmodule Rachel.Repo.Migrations.AddUserGameFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      add :display_name, :string
      add :avatar_url, :string
      add :games_played, :integer, default: 0
      add :games_won, :integer, default: 0
      add :total_turns, :integer, default: 0
      add :preferences, :map, default: %{}
      add :is_online, :boolean, default: false
      add :last_seen_at, :utc_datetime
    end

    create unique_index(:users, [:username])
  end
end
