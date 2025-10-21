defmodule Rachel.Game.Games do
  @moduledoc """
  Database schema and persistence layer for games.

  This module handles saving and loading game state to/from PostgreSQL,
  allowing games to survive server restarts and enabling game history.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Rachel.Repo
  alias Rachel.Game.GameState

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "games" do
    field :status, :string
    field :current_player_index, :integer
    field :direction, :string
    field :pending_attack_type, :string
    field :pending_attack_count, :integer
    field :pending_skips, :integer
    field :nominated_suit, :string
    field :turn_count, :integer
    field :deck_count, :integer
    field :expected_total_cards, :integer

    # JSONB fields - stored as lists in the database
    field :players, {:array, :map}
    field :deck, {:array, :map}
    field :discard_pile, {:array, :map}
    field :winners, {:array, :string}

    field :last_action_at, :utc_datetime

    timestamps()
  end

  @doc """
  Saves a GameState struct to the database.
  """
  def save_game(%GameState{} = game_state) do
    # Convert pending_attack tuple to separate fields
    {attack_type, attack_count} =
      case game_state.pending_attack do
        {type, count} -> {Atom.to_string(type), count}
        nil -> {nil, 0}
      end

    # Convert nominated_suit atom to string
    nominated_suit =
      if game_state.nominated_suit, do: Atom.to_string(game_state.nominated_suit), else: nil

    attrs = %{
      id: game_state.id,
      status: Atom.to_string(game_state.status),
      current_player_index: game_state.current_player_index,
      direction: Atom.to_string(game_state.direction),
      pending_attack_type: attack_type,
      pending_attack_count: attack_count,
      pending_skips: game_state.pending_skips,
      nominated_suit: nominated_suit,
      turn_count: game_state.turn_count,
      deck_count: game_state.deck_count,
      expected_total_cards: game_state.expected_total_cards,
      players: serialize_players(game_state.players),
      deck: serialize_cards(game_state.deck),
      discard_pile: serialize_cards(game_state.discard_pile),
      winners: game_state.winners,
      last_action_at: game_state.last_action_at
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :id
    )
  end

  @doc """
  Loads a game from the database and converts it to a GameState struct.
  """
  def load_game(game_id) do
    case Repo.get(__MODULE__, game_id) do
      nil ->
        {:error, :not_found}

      game ->
        {:ok, to_game_state(game)}
    end
  end

  @doc """
  Deletes a game from the database.
  """
  def delete_game(game_id) do
    case Repo.get(__MODULE__, game_id) do
      nil -> {:error, :not_found}
      game -> Repo.delete(game)
    end
  end

  @doc """
  Lists all games with a specific status.
  """
  def list_by_status(status) when is_atom(status) do
    status_string = Atom.to_string(status)

    __MODULE__
    |> where([g], g.status == ^status_string)
    |> Repo.all()
    |> Enum.map(&to_game_state/1)
  end

  @doc """
  Lists games that need cleanup based on status and last action time.
  """
  def list_stale_games do
    now = DateTime.utc_now()
    one_hour_ago = DateTime.add(now, -3600, :second)
    thirty_mins_ago = DateTime.add(now, -1800, :second)
    two_hours_ago = DateTime.add(now, -7200, :second)

    import Ecto.Query

    __MODULE__
    |> where(
      [g],
      (g.status == "finished" and g.last_action_at < ^one_hour_ago) or
        (g.status == "waiting" and g.last_action_at < ^thirty_mins_ago) or
        (g.status == "playing" and g.last_action_at < ^two_hours_ago)
    )
    |> Repo.all()
    |> Enum.map(& &1.id)
  end

  # Private functions

  defp changeset(game, attrs) do
    game
    |> cast(attrs, [
      :id,
      :status,
      :current_player_index,
      :direction,
      :pending_attack_type,
      :pending_attack_count,
      :pending_skips,
      :nominated_suit,
      :turn_count,
      :deck_count,
      :expected_total_cards,
      :players,
      :deck,
      :discard_pile,
      :winners,
      :last_action_at
    ])
    |> validate_required([
      :id,
      :status,
      :current_player_index,
      :direction,
      :turn_count,
      :deck_count,
      :expected_total_cards,
      :players,
      :deck,
      :discard_pile,
      :last_action_at
    ])
    |> validate_inclusion(:status, ["waiting", "playing", "finished", "corrupted"])
    |> validate_number(:current_player_index, greater_than_or_equal_to: 0)
    |> validate_inclusion(:direction, ["clockwise", "counter_clockwise"])
  end

  defp to_game_state(game) do
    # Convert pending_attack fields back to tuple
    pending_attack =
      if game.pending_attack_type do
        {String.to_existing_atom(game.pending_attack_type), game.pending_attack_count}
      else
        nil
      end

    # Convert nominated_suit string back to atom
    nominated_suit =
      if game.nominated_suit, do: String.to_existing_atom(game.nominated_suit), else: nil

    %GameState{
      id: game.id,
      status: String.to_existing_atom(game.status),
      current_player_index: game.current_player_index,
      direction: String.to_existing_atom(game.direction),
      pending_attack: pending_attack,
      pending_skips: game.pending_skips,
      nominated_suit: nominated_suit,
      turn_count: game.turn_count,
      deck_count: game.deck_count,
      expected_total_cards: game.expected_total_cards,
      players: deserialize_players(game.players),
      deck: deserialize_cards(game.deck),
      discard_pile: deserialize_cards(game.discard_pile),
      winners: game.winners,
      created_at: game.inserted_at,
      last_action_at: game.last_action_at
    }
  end

  defp serialize_players(players) do
    Enum.map(players, fn player ->
      %{
        "id" => player.id,
        "user_id" => player.user_id,
        "name" => player.name,
        "hand" => serialize_cards(player.hand),
        "type" => Atom.to_string(player.type),
        "status" => Atom.to_string(player.status),
        "difficulty" => if(player.difficulty, do: Atom.to_string(player.difficulty), else: nil)
      }
    end)
  end

  defp deserialize_players(players_data) when is_list(players_data) do
    Enum.map(players_data, fn player ->
      %{
        id: player["id"],
        user_id: player["user_id"],
        name: player["name"],
        hand: deserialize_cards(player["hand"]),
        type: String.to_existing_atom(player["type"]),
        status: String.to_existing_atom(player["status"]),
        difficulty:
          if(player["difficulty"], do: String.to_existing_atom(player["difficulty"]), else: nil)
      }
    end)
  end

  defp serialize_cards(cards) do
    Enum.map(cards, fn card ->
      %{
        "suit" => Atom.to_string(card.suit),
        "rank" => card.rank
      }
    end)
  end

  defp deserialize_cards(cards_data) when is_list(cards_data) do
    Enum.map(cards_data, fn card ->
      Rachel.Game.Card.new(
        String.to_existing_atom(card["suit"]),
        card["rank"]
      )
    end)
  end
end
