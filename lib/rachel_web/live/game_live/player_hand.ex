defmodule RachelWeb.GameLive.PlayerHand do
  @moduledoc """
  Component for displaying the human player's hand and action buttons.
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <!-- Your Hand -->
      <%= if @player && @player.type == :human do %>
        <div class="player-hand bg-white/20 rounded-lg p-4">
          <div class="text-white text-center mb-4">
            Your Hand
            <%= if @is_your_turn do %>
              <span class="text-yellow-400 text-sm ml-2">← Your Turn</span>
            <% end %>
          </div>
          <div class="flex flex-wrap justify-center gap-2">
            <%= for card <- @player.hand do %>
              <% is_playable =
                @is_your_turn &&
                  (card in @selected_cards || card_playable?(@game, card, @selected_cards)) %>
              <.card_display
                card={card}
                clickable={is_playable}
                selected={card in @selected_cards}
                playable={
                  @is_your_turn &&
                    card_playable?(@game, card, @selected_cards)
                }
                in_hand={true}
                phx-click={if is_playable, do: "toggle_card", else: nil}
                phx-value-suit={card.suit}
                phx-value-rank={card.rank}
              />
            <% end %>
          </div>
        </div>
        
    <!-- Single Action Button (Only on Your Turn) -->
        <%= if @is_your_turn do %>
          <div class="flex justify-center mt-6">
            <%= if length(@selected_cards) > 0 do %>
              <button
                phx-click="attempt_play_cards"
                class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg text-lg"
              >
                Play Selected Cards
              </button>
            <% else %>
              <button
                phx-click="draw_card"
                class="bg-yellow-600 hover:bg-yellow-700 text-white px-8 py-3 rounded-lg text-lg"
              >
                {@button_text}
              </button>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Helper function - delegates to GameHelpers
  defp card_playable?(game, card, selected_cards) do
    RachelWeb.GameLive.GameHelpers.card_playable?(game, card, selected_cards)
  end
end
