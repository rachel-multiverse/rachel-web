defmodule RachelWeb.GameLive.OpponentHands do
  @moduledoc """
  Component for displaying opponent hands (other players excluding human player at index 0).
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="flex justify-center gap-4 mb-8">
      <%= for {player, index} <- Enum.with_index(@game.players) do %>
        <%= if index > 0 do %>
          <div class={[
            "opponent-hand rounded-lg p-4",
            if(player.type == :ai, do: "bg-purple-800/20", else: "bg-white/10"),
            index == @game.current_player_index && "ring-2 ring-yellow-400"
          ]}>
            <div class="text-white text-center mb-2">
              {player.name}
              <%= if player.type == :ai do %>
                <span class="text-purple-300 text-xs">🤖</span>
              <% end %>
              <%= if index == @game.current_player_index do %>
                <div class="text-yellow-400 text-xs">← Current</div>
              <% end %>
              <%= if player.status == :won do %>
                <div class="text-green-400 text-xs">✓ Won</div>
              <% end %>
            </div>
            <div class="flex gap-1">
              <%= for _ <- 1..length(player.hand) do %>
                <div class="w-12 h-16 bg-blue-900 rounded border-2 border-white"></div>
              <% end %>
            </div>
            <div class="text-center text-sm text-white/70 mt-2">
              {length(player.hand)} cards
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
