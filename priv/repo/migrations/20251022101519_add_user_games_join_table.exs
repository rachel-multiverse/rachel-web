defmodule Rachel.Repo.Migrations.AddUserGamesJoinTable do
  use Ecto.Migration

  def change do
    create table(:user_games, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :final_rank, :integer
      add :turns_taken, :integer, default: 0

      timestamps()
    end

    create index(:user_games, [:user_id])
    create index(:user_games, [:game_id])
    create unique_index(:user_games, [:user_id, :game_id])
  end
end
