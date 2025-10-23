defmodule Rachel.Repo.Migrations.CreateAnalyticsTables do
  use Ecto.Migration

  def change do
    # Game stats table
    create table(:game_stats) do
      add :game_id, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :duration_seconds, :integer
      add :total_turns, :integer
      add :player_count, :integer, null: false
      add :ai_count, :integer, null: false
      # 'user', 'anonymous', 'ai'
      add :winner_type, :string
      # 'easy', 'medium', 'hard' if AI won
      add :winner_ai_difficulty, :string
      add :abandoned, :boolean, default: false
      add :deck_count, :integer, default: 1

      timestamps()
    end

    create index(:game_stats, [:started_at])
    create index(:game_stats, [:winner_type])
    create index(:game_stats, [:duration_seconds])
    create index(:game_stats, [:game_id])

    # Card play stats table
    create table(:card_play_stats) do
      add :game_id, :string, null: false
      # 'user', 'anonymous', 'ai'
      add :player_type, :string, null: false
      # if AI player
      add :ai_difficulty, :string
      add :turn_number, :integer, null: false
      # JSONB array of cards
      add :cards_played, :map, null: false
      add :was_stacked, :boolean, default: false
      add :stack_size, :integer, default: 1
      # if Ace was played
      add :nominated_suit, :string
      add :resulted_in_win, :boolean, default: false
      add :played_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:card_play_stats, [:game_id])
    create index(:card_play_stats, [:played_at])

    # Card draw stats table
    create table(:card_draw_stats) do
      add :game_id, :string, null: false
      add :player_type, :string, null: false
      add :ai_difficulty, :string
      add :turn_number, :integer, null: false
      add :cards_drawn, :integer, null: false
      # 'cannot_play', 'attack_penalty', 'voluntary'
      add :reason, :string, null: false
      # '2', '7', 'black_jack' if attack penalty
      add :attack_type, :string
      add :drawn_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:card_draw_stats, [:game_id])
    create index(:card_draw_stats, [:reason])
    create index(:card_draw_stats, [:drawn_at])
  end
end
