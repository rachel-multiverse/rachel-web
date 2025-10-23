defmodule Rachel.Analytics.GameStat do
  @moduledoc """
  Schema for game statistics tracking.

  Records high-level game metrics including duration, player counts,
  winner information, and game completion status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_stats" do
    field :game_id, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :duration_seconds, :integer
    field :total_turns, :integer
    field :player_count, :integer
    field :ai_count, :integer
    field :winner_type, :string
    field :winner_ai_difficulty, :string
    field :abandoned, :boolean, default: false
    field :deck_count, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(game_stat, attrs) do
    game_stat
    |> cast(attrs, [
      :game_id,
      :started_at,
      :finished_at,
      :duration_seconds,
      :total_turns,
      :player_count,
      :ai_count,
      :winner_type,
      :winner_ai_difficulty,
      :abandoned,
      :deck_count
    ])
    |> validate_required([
      :game_id,
      :started_at,
      :player_count,
      :ai_count
    ])
    |> validate_inclusion(:winner_type, ["user", "anonymous", "ai"])
    |> validate_inclusion(:winner_ai_difficulty, ["easy", "medium", "hard"])
    |> validate_number(:player_count, greater_than: 0)
    |> validate_number(:ai_count, greater_than_or_equal_to: 0)
    |> validate_number(:deck_count, greater_than: 0)
  end
end
