defmodule Rachel.GameManager do
  @moduledoc """
  High-level API for managing Rachel games.
  """

  alias Rachel.Game.{GameSupervisor, GameServer}

  @doc """
  Creates a new game with the given players.
  """
  def create_game(player_names) when is_list(player_names) and length(player_names) >= 2 do
    case GameSupervisor.start_game(player_names) do
      {:ok, game_id} -> 
        {:ok, game_id}
      error -> 
        error
    end
  end

  @doc """
  Creates a new lobby game that players can join.
  """
  def create_lobby(host_name) do
    case GameSupervisor.start_game([host_name]) do
      {:ok, game_id} -> 
        {:ok, game_id}
      error -> 
        error
    end
  end

  @doc """
  Joins a player to a lobby game.
  """
  def join_game(game_id, player_name) do
    GameServer.add_player(game_id, player_name)
  end

  @doc """
  Starts a game that's in the waiting state.
  """
  def start_game(game_id) do
    GameServer.start_game(game_id)
  end

  @doc """
  Gets the current state of a game.
  """
  def get_game(game_id) do
    GameServer.get_state(game_id)
  catch
    :exit, {:noproc, _} -> {:error, :game_not_found}
  end

  @doc """
  Player plays cards.
  """
  def play_cards(game_id, player_id, cards, nominated_suit \\ nil) do
    GameServer.play_cards(game_id, player_id, cards, nominated_suit)
  catch
    :exit, {:noproc, _} -> {:error, :game_not_found}
  end

  @doc """
  Player draws cards.
  """
  def draw_cards(game_id, player_id, reason \\ :cannot_play) do
    GameServer.draw_cards(game_id, player_id, reason)
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
    GameServer.subscribe(game_id)
  end

  @doc """
  Unsubscribes from game updates.
  """
  def unsubscribe_from_game(game_id) do
    GameServer.unsubscribe(game_id)
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
        {:ok, %{
          id: game.id,
          status: game.status,
          player_count: length(game.players),
          players: Enum.map(game.players, &(&1.name)),
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
end