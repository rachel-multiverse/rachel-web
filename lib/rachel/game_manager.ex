defmodule Rachel.GameManager do
  @moduledoc """
  High-level API for managing Rachel games.
  """

  alias Rachel.Game.{GameEngine, Games, GameSupervisor}

  @doc """
  Creates a new game with the given players.
  Players can be:
    - {:user, user_id, name} for authenticated users
    - {:anonymous, name} for anonymous players
    - {:ai, name, difficulty} for AI players
    - Strings (backwards compat, treated as anonymous)
  """
  def create_game(players) when is_list(players) and length(players) >= 2 do
    case GameSupervisor.start_game(players) do
      {:ok, game_id} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  @doc """
  Creates a game with AI opponents.
  Player can be {:user, user_id, name}, {:anonymous, name}, or a string.
  """
  def create_ai_game(player, num_ai \\ 3, difficulty \\ :medium) do
    ai_players =
      for i <- 1..num_ai do
        name = Rachel.Game.AIPlayer.personality_name(difficulty, i - 1)
        {:ai, name, difficulty}
      end

    players = [player | ai_players]
    create_game(players)
  end

  @doc """
  Creates a new lobby game that players can join.
  Host can be {:user, user_id, name}, {:anonymous, name}, or a string.
  """
  def create_lobby(host) do
    case GameSupervisor.start_game([host]) do
      {:ok, game_id} ->
        {:ok, game_id}

      error ->
        error
    end
  end

  @doc """
  Joins a player to a lobby game.
  """
  def join_game(game_id, player_name, user_id \\ nil) do
    GameEngine.add_player(game_id, player_name, user_id)
  end

  @doc """
  Starts a game that's in the waiting state.
  """
  def start_game(game_id) do
    GameEngine.start_game(game_id)
  end

  @doc """
  Gets the current state of a game.
  """
  def get_game(game_id) do
    GameEngine.get_state(game_id)
  catch
    :exit, {:noproc, _} -> {:error, :game_not_found}
  end

  @doc """
  Player plays cards.
  """
  def play_cards(game_id, player_id, cards, nominated_suit \\ nil) do
    GameEngine.play_cards(game_id, player_id, cards, nominated_suit)
  catch
    :exit, {:noproc, _} -> {:error, :game_not_found}
  end

  @doc """
  Player draws cards.
  """
  def draw_cards(game_id, player_id, reason \\ :cannot_play) do
    GameEngine.draw_cards(game_id, player_id, reason)
  catch
    :exit, {:noproc, _} -> {:error, :game_not_found}
  end

  @doc """
  Lists all active games.
  """
  def list_games do
    GameSupervisor.list_games()
  end

  @doc """
  Subscribes to game updates.
  """
  def subscribe_to_game(game_id) do
    GameEngine.subscribe(game_id)
  end

  @doc """
  Unsubscribes from game updates.
  """
  def unsubscribe_from_game(game_id) do
    GameEngine.unsubscribe(game_id)
  end

  @doc """
  Ends a game.
  """
  def end_game(game_id) do
    GameSupervisor.stop_game(game_id)
  end

  @doc """
  Gets public game info (for listing).
  """
  def get_game_info(game_id) do
    case get_game(game_id) do
      {:ok, game} ->
        {:ok,
         %{
           id: game.id,
           status: game.status,
           player_count: length(game.players),
           players: Enum.map(game.players, & &1.name),
           created_at: game.created_at
         }}

      error ->
        error
    end
  end

  @doc """
  Validates if a player can perform an action.
  """
  def can_play?(game_id, player_id) do
    case get_game(game_id) do
      {:ok, game} ->
        current_player = Enum.at(game.players, game.current_player_index)
        current_player && current_player.id == player_id

      _ ->
        false
    end
  end

  @doc """
  Saves a game state to the database.
  """
  def save_game(game_state) do
    Games.save_game(game_state)
  end

  @doc """
  Loads a game state from the database.
  """
  def load_game(game_id) do
    Games.load_game(game_id)
  end

  @doc """
  Deletes a game from the database.
  """
  def delete_game_record(game_id) do
    Games.delete_game(game_id)
  end

  @doc """
  Restores all active games from the database on application startup.
  Returns a list of restored game IDs.
  """
  def restore_active_games do
    # Load all non-finished games
    playing_games = Games.list_by_status(:playing)
    waiting_games = Games.list_by_status(:waiting)

    all_games = playing_games ++ waiting_games

    Enum.reduce(all_games, [], fn game_state, acc ->
      case GameSupervisor.restore_game(game_state) do
        {:ok, game_id} ->
          [game_id | acc]

        {:error, reason} ->
          require Logger

          Logger.warning("Failed to restore game #{game_state.id}: #{inspect(reason)}")

          acc
      end
    end)
  end
end
