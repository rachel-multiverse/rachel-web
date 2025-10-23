defmodule Rachel.Analytics.CardDrawStat do
  @moduledoc """
  Schema for tracking card draw events during games.

  Records when and why players draw cards, including attack penalties,
  inability to play, or voluntary draws.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "card_draw_stats" do
    field :game_id, :string
    field :player_type, :string
    field :ai_difficulty, :string
    field :turn_number, :integer
    field :cards_drawn, :integer
    field :reason, :string
    field :attack_type, :string
    field :drawn_at, :utc_datetime

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(card_draw_stat, attrs) do
    card_draw_stat
    |> cast(attrs, [
      :game_id,
      :player_type,
      :ai_difficulty,
      :turn_number,
      :cards_drawn,
      :reason,
      :attack_type,
      :drawn_at
    ])
    |> validate_required([
      :game_id,
      :player_type,
      :turn_number,
      :cards_drawn,
      :reason,
      :drawn_at
    ])
    |> validate_inclusion(:player_type, ["user", "anonymous", "ai"])
    |> validate_inclusion(:ai_difficulty, ["easy", "medium", "hard"])
    |> validate_inclusion(:reason, ["cannot_play", "attack_penalty", "voluntary"])
    |> validate_inclusion(:attack_type, ["2", "7", "black_jack"])
    |> validate_number(:turn_number, greater_than: 0)
    |> validate_number(:cards_drawn, greater_than: 0)
  end
end
