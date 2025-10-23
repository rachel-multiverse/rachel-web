defmodule Rachel.Analytics.CardPlayStat do
  @moduledoc """
  Schema for tracking individual card plays during games.

  Records every card play action including player type, cards played,
  stacking information, and whether the play resulted in a win.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "card_play_stats" do
    field :game_id, :string
    field :player_type, :string
    field :ai_difficulty, :string
    field :turn_number, :integer
    field :cards_played, :map
    field :was_stacked, :boolean, default: false
    field :stack_size, :integer, default: 1
    field :nominated_suit, :string
    field :resulted_in_win, :boolean, default: false
    field :played_at, :utc_datetime

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(card_play_stat, attrs) do
    card_play_stat
    |> cast(attrs, [
      :game_id,
      :player_type,
      :ai_difficulty,
      :turn_number,
      :cards_played,
      :was_stacked,
      :stack_size,
      :nominated_suit,
      :resulted_in_win,
      :played_at
    ])
    |> validate_required([
      :game_id,
      :player_type,
      :turn_number,
      :cards_played,
      :played_at
    ])
    |> validate_inclusion(:player_type, ["user", "anonymous", "ai"])
    |> validate_inclusion(:ai_difficulty, ["easy", "medium", "hard"])
    |> validate_inclusion(:nominated_suit, ["hearts", "diamonds", "clubs", "spades"])
    |> validate_number(:turn_number, greater_than: 0)
    |> validate_number(:stack_size, greater_than: 0)
  end
end
