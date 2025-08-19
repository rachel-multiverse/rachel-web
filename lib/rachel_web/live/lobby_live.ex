defmodule RachelWeb.LobbyLive do
  use RachelWeb, :live_view

  alias Rachel.GameManager

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(2000, :refresh_games)
    end

    {:ok,
     socket
     |> assign(:games, list_games())
     |> assign(:player_name, "")
     |> assign(:creating_game, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-900 p-8">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-12">
          <h1 class="text-6xl font-bold text-white mb-4">Rachel</h1>
          <p class="text-xl text-green-200">The Classic Card Game</p>
        </div>
        
    <!-- Create Game Section -->
        <div class="bg-white rounded-lg shadow-xl p-8 mb-8">
          <h2 class="text-2xl font-bold mb-4">Quick Play</h2>

          <form phx-submit="create_game" class="space-y-4">
            <div>
              <label class="block text-sm font-medium mb-2">Your Name</label>
              <input
                type="text"
                name="player_name"
                value={@player_name}
                phx-change="update_name"
                placeholder="Enter your name"
                class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-green-500"
                required
              />
            </div>

            <div class="flex gap-4">
              <button
                type="submit"
                name="game_type"
                value="ai"
                class="flex-1 bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-semibold"
                disabled={@creating_game || @player_name == ""}
              >
                Play vs AI
              </button>

              <button
                type="submit"
                name="game_type"
                value="multiplayer"
                class="flex-1 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-semibold"
                disabled={@creating_game || @player_name == ""}
              >
                Create Multiplayer Game
              </button>
            </div>
          </form>
        </div>
        
    <!-- Active Games -->
        <div class="bg-white rounded-lg shadow-xl p-8">
          <h2 class="text-2xl font-bold mb-4">Active Games</h2>

          <%= if @games == [] do %>
            <p class="text-gray-500 text-center py-8">No active games. Create one to get started!</p>
          <% else %>
            <div class="space-y-2">
              <%= for game <- @games do %>
                <div class="border rounded-lg p-4 flex justify-between items-center hover:bg-gray-50">
                  <div>
                    <div class="font-semibold">Game {String.slice(game.id, 0..7)}</div>
                    <div class="text-sm text-gray-600">
                      Players: {game.player_count} |
                      Status: {game.status}
                    </div>
                  </div>

                  <%= if game.status == :waiting do %>
                    <button
                      phx-click="join_game"
                      phx-value-game-id={game.id}
                      class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
                      disabled={@player_name == ""}
                    >
                      Join Game
                    </button>
                  <% else %>
                    <button
                      phx-click="spectate_game"
                      phx-value-game-id={game.id}
                      class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded"
                    >
                      Spectate
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Instructions -->
        <div class="mt-8 bg-white/10 rounded-lg p-6 text-white">
          <h3 class="text-lg font-semibold mb-2">How to Play</h3>
          <ul class="text-sm space-y-1 text-green-100">
            <li>• Match cards by suit or rank</li>
            <li>• 2s make opponents draw 2 cards</li>
            <li>• 7s skip the next player</li>
            <li>• Queens reverse direction</li>
            <li>• Black Jacks (♠♣) make opponents draw 5</li>
            <li>• Red Jacks (♥♦) counter Black Jacks</li>
            <li>• Aces let you choose the suit</li>
            <li>• First to empty their hand wins!</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_name", %{"player_name" => name}, socket) do
    {:noreply, assign(socket, :player_name, name)}
  end

  @impl true
  def handle_event("create_game", %{"player_name" => name, "game_type" => type}, socket) do
    socket = assign(socket, :creating_game, true)

    case create_game_with_type(name, type) do
      {:ok, game_id} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create game")
         |> assign(:creating_game, false)}
    end
  end

  @impl true
  def handle_event("join_game", %{"game-id" => game_id}, socket) do
    case GameManager.join_game(game_id, socket.assigns.player_name) do
      {:ok, _player_id} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join game")}
    end
  end

  @impl true
  def handle_event("spectate_game", %{"game-id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_info(:refresh_games, socket) do
    {:noreply, assign(socket, :games, list_games())}
  end

  # Private functions

  defp create_game_with_type(player_name, "ai") do
    # Create a game with AI players
    case GameManager.create_ai_game(player_name, 3, :medium) do
      {:ok, game_id} ->
        # Auto-start AI games
        GameManager.start_game(game_id)
        {:ok, game_id}

      error ->
        error
    end
  end

  defp create_game_with_type(player_name, "multiplayer") do
    GameManager.create_lobby(player_name)
  end

  defp list_games do
    GameManager.list_games()
    |> Enum.map(&get_game_info/1)
    |> Enum.reject(&is_nil/1)
  end

  defp get_game_info(game_id) do
    case GameManager.get_game_info(game_id) do
      {:ok, info} -> info
      _ -> nil
    end
  end
end
