defmodule Rachel.Repo.Migrations.AddGamesTable do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :string, null: false
      add :current_player_index, :integer, null: false, default: 0
      add :direction, :string, null: false, default: "clockwise"
      add :pending_attack_type, :string
      add :pending_attack_count, :integer, default: 0
      add :pending_skips, :integer, default: 0
      add :nominated_suit, :string
      add :turn_count, :integer, null: false, default: 0
      add :deck_count, :integer, null: false, default: 1
      add :expected_total_cards, :integer, null: false, default: 52

      # JSON fields for complex data
      add :players, :jsonb, null: false
      add :deck, :jsonb, null: false
      add :discard_pile, :jsonb, null: false
      add :winners, :jsonb, default: "[]"

      timestamps()
      add :last_action_at, :utc_datetime, null: false
    end

    create index(:games, [:status])
    create index(:games, [:last_action_at])
  end
end
