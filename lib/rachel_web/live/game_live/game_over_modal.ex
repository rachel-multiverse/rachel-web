defmodule RachelWeb.GameLive.GameOverModal do
  @moduledoc """
  Component for displaying the game over screen with winner celebration.
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50">
      <div class="bg-gradient-to-br from-yellow-400 to-orange-500 rounded-2xl p-8 shadow-2xl text-center max-w-md mx-4">
        <div class="text-6xl mb-4">🎉</div>
        <h1 class="text-4xl font-bold text-white mb-4">Game Over!</h1>

        <%= if length(@game.winners) > 0 do %>
          <div class="mb-6">
            <% winner_id = List.first(@game.winners) %>
            <% winner = Enum.find(@game.players, &(&1.id == winner_id)) %>
            <div class="text-2xl font-bold text-white mb-2">
              🏆 {winner.name} Wins! 🏆
            </div>
          </div>
        <% end %>

          <div class="mb-6 text-white">
            <p class="text-lg mb-4">Final Statistics:</p>
            <div class="bg-black bg-opacity-20 rounded-lg p-4 space-y-2">
              <div class="flex justify-between">
                <span>Total Turns:</span>
                <span class="font-bold">{@game.turn_count}</span>
              </div>
              <div class="flex justify-between">
                <span>Players:</span>
                <span class="font-bold">{length(@game.players)}</span>
              </div>
              <%= if @game.winners && length(@game.winners) > 0 do %>
                <div class="border-t border-white border-opacity-20 pt-2">
                  <div class="text-sm">Final Standings:</div>
                  <%= for {player, index} <- Enum.with_index(@game.players) do %>
                    <div class="flex justify-between text-sm">
                      <span class="flex items-center gap-1">
                        <%= if player.id == List.first(@game.winners) do %>
                          <span class="text-yellow-300">🏆</span>
                        <% else %>
                          <span class="text-gray-300">{index + 1}.</span>
                        <% end %>
                        {player.name}
                      </span>
                      <span>{length(player.hand)} cards left</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

        <div class="flex gap-4 justify-center">
          <button
            phx-click="new_game"
            class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-bold transition-colors"
          >
            Play Again
          </button>
          <a
            href="/"
            class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-3 rounded-lg font-bold transition-colors"
          >
            Back to Lobby
          </a>
        </div>
      </div>
      
    <!-- Confetti Animation -->
      <div class="fixed inset-0 pointer-events-none z-60 overflow-hidden">
        <%= for i <- 1..20 do %>
          <% emoji = Enum.random(["🎊", "🎉", "✨", "🎈", "🌟"]) %>
          <% left_pos = rem(i * 17 + 13, 100) %>
          <% delay = rem(i * 137, 1500) %>
          <% duration = 2000 + rem(i * 211, 1500) %>
          <div
            class="absolute text-3xl"
            style={"left: #{left_pos}%; top: -50px; animation: confetti-fall #{duration}ms ease-in #{delay}ms 1 forwards;"}
          >
            {emoji}
          </div>
        <% end %>
      </div>
      
    <!-- Victory Sound Effect Trigger -->
      <div phx-hook="VictorySound" id="victory-sound" class="hidden"></div>
    </div>
    """
  end
end
