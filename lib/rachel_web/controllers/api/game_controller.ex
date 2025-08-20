defmodule RachelWeb.API.GameController do
  use RachelWeb, :controller
  
  alias Rachel.GameManager
  
  def index(conn, _params) do
    games = 
      GameManager.list_games()
      |> Enum.map(&get_game_info/1)
      |> Enum.reject(&is_nil/1)
    
    json(conn, %{games: games})
  end
  
  def create(conn, %{"type" => "ai"}) do
    user = conn.assigns.current_user
    
    case GameManager.create_ai_game(user.username, 3, :medium) do
      {:ok, game_id} ->
        GameManager.start_game(game_id)
        {:ok, game} = GameManager.get_game(game_id)
        
        json(conn, %{game: game_json(game)})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity) 
        |> json(%{error: to_string(reason)})
    end
  end
  
  def create(conn, %{"type" => "multiplayer"}) do
    user = conn.assigns.current_user
    
    case GameManager.create_lobby(user.username) do
      {:ok, game_id} ->
        {:ok, game} = GameManager.get_game(game_id)
        
        json(conn, %{game: game_json(game)})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
  
  def show(conn, %{"id" => game_id}) do
    case GameManager.get_game(game_id) do
      {:ok, game} ->
        json(conn, %{game: game_json(game)})
        
      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Game not found"})
    end
  end
  
  def join(conn, %{"id" => game_id}) do
    user = conn.assigns.current_user
    
    case GameManager.join_game(game_id, user.username) do
      {:ok, _player_id} ->
        {:ok, game} = GameManager.get_game(game_id)
        json(conn, %{game: game_json(game)})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
  
  def play_cards(conn, %{"id" => game_id, "cards" => cards, "suit" => suit}) do
    user = conn.assigns.current_user
    parsed_cards = parse_cards(cards)
    nominated_suit = if suit && suit != "", do: String.to_existing_atom(suit), else: nil
    
    case GameManager.play_cards(game_id, user.id, parsed_cards, nominated_suit) do
      {:ok, game} ->
        json(conn, %{game: game_json(game)})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
  
  def draw_cards(conn, %{"id" => game_id}) do
    user = conn.assigns.current_user
    
    case GameManager.draw_cards(game_id, user.id, :cannot_play) do
      {:ok, game} ->
        json(conn, %{game: game_json(game)})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
  
  defp get_game_info(game_id) do
    case GameManager.get_game_info(game_id) do
      {:ok, info} -> info
      _ -> nil
    end
  end
  
  defp game_json(game) do
    %{
      id: game.id,
      status: game.status,
      players: Enum.map(game.players, &player_json/1),
      current_player_index: game.current_player_index,
      direction: game.direction,
      turn_count: game.turn_count,
      deck_size: length(game.deck),
      top_card: if(game.discard_pile != [], do: card_json(hd(game.discard_pile)), else: nil),
      nominated_suit: game.nominated_suit,
      pending_attack: game.pending_attack,
      pending_skips: game.pending_skips,
      winners: game.winners
    }
  end
  
  defp player_json(player) do
    %{
      id: player.id,
      name: player.name,
      type: player.type,
      status: player.status,
      hand_size: length(player.hand),
      # Only include actual cards if it's the current user
      hand: if(player.type == :human, do: Enum.map(player.hand, &card_json/1), else: nil)
    }
  end
  
  defp card_json(card) do
    %{
      suit: card.suit,
      rank: card.rank
    }
  end
  
  defp parse_cards(cards) when is_list(cards) do
    Enum.map(cards, fn %{"suit" => suit, "rank" => rank} ->
      Rachel.Game.Card.new(String.to_existing_atom(suit), rank)
    end)
  end
end