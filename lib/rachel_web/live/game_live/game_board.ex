defmodule RachelWeb.GameLive.GameBoard do
  @moduledoc """
  Component for the central game board showing deck, discard pile, and game status.
  """
  use Phoenix.LiveComponent

  # Import card_display component from parent GameLive
  import RachelWeb.GameLive, only: [card_display: 1]

  def render(assigns) do
    ~H"""
    <div>
      <!-- Game Header -->
      <div class="bg-white rounded-lg shadow-lg p-4 mb-4">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-bold">Rachel Game</h1>
          <div class="flex gap-4">
            <span class="text-sm">Turn: {@game.turn_count}</span>
            <span class={[
              "text-sm font-semibold px-3 py-1 rounded-lg transition-all",
              @is_your_turn && "your-turn bg-yellow-400 text-black",
              !@is_your_turn && "bg-gray-600 text-white"
            ]}>
              {if @is_your_turn,
                do: "🎮 Your Turn!",
                else: @current_player_name <> "'s turn"}
            </span>
            <span class="text-sm flex items-center gap-1">
              Direction: {@direction_symbol}
            </span>
          </div>
        </div>
      </div>

    <!-- Play Area -->
      <div class="flex justify-center gap-8 mb-8">
        <!-- Deck -->
        <div class="deck-area">
          <div class="text-white text-center mb-2">Deck</div>
          <div class="w-20 h-28 bg-blue-900 rounded-lg border-4 border-white shadow-xl flex items-center justify-center">
            <span class="text-white text-2xl font-bold">{length(@game.deck)}</span>
          </div>
        </div>

    <!-- Discard Pile -->
        <div class="discard-area">
          <div class="text-white text-center mb-2">Discard</div>
          <%= if top_card = List.first(@game.discard_pile) do %>
            <.card_display card={top_card} clickable={false} selected={false} playable={false} />
          <% end %>
          <%= if @game.nominated_suit do %>
            <div class="mt-2 text-center">
              <span class="bg-white px-2 py-1 rounded">
                Suit: {@game.nominated_suit}
              </span>
            </div>
          <% end %>
        </div>
      </div>

    <!-- Game Status Messages -->
      <%= if @game.pending_attack do %>
        <div class="text-center mb-4">
          <span class="attack-counter bg-red-600 text-white px-4 py-2 rounded-lg inline-block font-bold">
            ⚔️ Attack pending: {@attack_description}
          </span>
        </div>
      <% end %>

      <%= if @game.pending_skips > 0 do %>
        <div class="text-center mb-4">
          <span class="skip-counter bg-yellow-600 text-white px-4 py-2 rounded-lg inline-block font-bold">
            ⏭️ Skips pending: {@game.pending_skips}
          </span>
        </div>
      <% end %>
    </div>
    """
  end
end
