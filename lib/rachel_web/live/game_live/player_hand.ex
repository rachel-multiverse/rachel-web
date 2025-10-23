defmodule RachelWeb.GameLive.PlayerHand do
  @moduledoc """
  Component for displaying the human player's hand and action buttons.
  """
  use Phoenix.LiveComponent

  # Import card_display component from parent GameLive
  import RachelWeb.GameLive, only: [card_display: 1]

  def render(assigns) do
    ~H"""
    <div>
      <!-- Your Hand -->
      <%= if @player && @player.type == :human do %>
        <div class="player-hand bg-white/20 rounded-lg p-4" id="player-hand-cards" phx-hook="CardDrawAnimation">
          <div class="text-white text-center mb-4">
            Your Hand
            <%= if @is_your_turn do %>
              <span class="text-yellow-400 text-sm ml-2">← Your Turn</span>
            <% end %>
          </div>
          <div class="flex flex-wrap justify-center gap-2" id="card-play-area" phx-hook="SwipeGestures">
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
                phx-disable-with="Playing..."
                class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg text-lg transition-all duration-200 active:scale-95 disabled:opacity-70 disabled:cursor-wait flex items-center justify-center gap-2"
              >
                <span class="button-text">Play Selected Cards</span>
                <span class="loading-spinner hidden">
                  <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                </span>
              </button>
            <% else %>
              <button
                phx-click="draw_card"
                phx-disable-with="Drawing..."
                class="bg-yellow-600 hover:bg-yellow-700 text-white px-8 py-3 rounded-lg text-lg transition-all duration-200 active:scale-95 disabled:opacity-70 disabled:cursor-wait flex items-center justify-center gap-2"
              >
                <span class="button-text">{@button_text}</span>
                <span class="loading-spinner hidden">
                  <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                </span>
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
