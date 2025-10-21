defmodule RachelWeb.GameLive.SuitModal do
  @moduledoc """
  Component for choosing a suit when playing an Ace.
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      phx-click="close_suit_modal"
    >
      <div class="bg-white rounded-lg p-6 shadow-xl" phx-click-away="close_suit_modal">
        <h3 class="text-lg font-bold mb-4 text-center">Choose Suit for Ace</h3>
        <div class="grid grid-cols-2 gap-4">
          <button
            phx-click="play_cards"
            phx-value-suit="hearts"
            class="bg-red-600 hover:bg-red-700 text-white px-6 py-4 rounded-lg text-center flex flex-col items-center gap-2"
          >
            <span class="text-3xl">♥</span>
            <span>Hearts</span>
          </button>
          <button
            phx-click="play_cards"
            phx-value-suit="diamonds"
            class="bg-red-600 hover:bg-red-700 text-white px-6 py-4 rounded-lg text-center flex flex-col items-center gap-2"
          >
            <span class="text-3xl">♦</span>
            <span>Diamonds</span>
          </button>
          <button
            phx-click="play_cards"
            phx-value-suit="clubs"
            class="bg-gray-800 hover:bg-gray-900 text-white px-6 py-4 rounded-lg text-center flex flex-col items-center gap-2"
          >
            <span class="text-3xl">♣</span>
            <span>Clubs</span>
          </button>
          <button
            phx-click="play_cards"
            phx-value-suit="spades"
            class="bg-gray-800 hover:bg-gray-900 text-white px-6 py-4 rounded-lg text-center flex flex-col items-center gap-2"
          >
            <span class="text-3xl">♠</span>
            <span>Spades</span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
