defmodule Rachel.Repo.Migrations.AddLeaderboardFields do
  use Ecto.Migration

  def change do
    # Add Elo fields to users
    alter table(:users) do
      add :elo_rating, :integer, default: 1000, null: false
      add :elo_games_played, :integer, default: 0, null: false
      add :elo_tier, :string, default: "bronze", null: false
    end

    # Create rating history table
    create table(:rating_history) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, type: :binary_id, on_delete: :nilify_all)
      add :rating_before, :integer, null: false
      add :rating_after, :integer, null: false
      add :rating_change, :integer, null: false
      add :game_position, :integer
      add :opponents_count, :integer

      timestamps(updated_at: false)
    end

    # Indexes for leaderboard queries
    create index(:users, [:elo_rating])
    create index(:rating_history, [:user_id])
    create index(:rating_history, [:inserted_at])
  end
end
