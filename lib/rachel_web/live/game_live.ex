defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.GameManager
  alias Rachel.Game.Card

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      GameManager.subscribe_to_game(game_id)
    end

    case GameManager.get_game(game_id) do
      {:ok, game} ->
        {:ok,
         socket
         |> assign(:game_id, game_id)
         |> assign(:game, game)
         |> assign(:current_player, current_player(game))
         |> assign(:selected_cards, [])
         |> assign(:nominated_suit, nil)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-container min-h-screen bg-green-900 p-4">
      <div class="max-w-7xl mx-auto">
        <!-- Game Header -->
        <div class="bg-white rounded-lg shadow-lg p-4 mb-4">
          <div class="flex justify-between items-center">
            <div class="flex items-center gap-4">
              <h1 class="text-2xl font-bold">Rachel Game</h1>
              <.link
                navigate={~p"/lobby"}
                class="text-sm text-blue-600 hover:text-blue-800"
              >
                ← Back to Lobby
              </.link>
            </div>
            <div class="flex gap-6 items-center">
              <span class="text-sm">Turn: <%= @game.turn_count %></span>
              <span class="text-sm">
                Current Player: <%= current_player_name(@game) %>
              </span>
              <div class="border-l pl-4">
                <span class="text-sm text-gray-600">
                  Playing as: <span class="font-semibold"><%= @current_user.username %></span>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Opponents Area -->
        <div class="flex justify-center gap-4 mb-8">
          <%= for {player, index} <- Enum.with_index(@game.players) do %>
            <%= if index != @game.current_player_index do %>
              <div class="opponent-hand bg-white/10 rounded-lg p-4">
                <div class="text-white text-center mb-2"><%= player.name %></div>
                <div class="flex gap-1">
                  <%= for _ <- 1..length(player.hand) do %>
                    <div class="w-12 h-16 bg-blue-900 rounded border-2 border-white"></div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Play Area -->
        <div class="flex justify-center gap-8 mb-8">
          <!-- Deck -->
          <div class="deck-area">
            <div class="text-white text-center mb-2">Deck</div>
            <div class="w-20 h-28 bg-blue-900 rounded-lg border-4 border-white shadow-xl flex items-center justify-center">
              <span class="text-white text-2xl font-bold"><%= length(@game.deck) %></span>
            </div>
          </div>

          <!-- Discard Pile -->
          <div class="discard-area">
            <div class="text-white text-center mb-2">Discard</div>
            <%= if top_card = List.first(@game.discard_pile) do %>
              <.card_display card={top_card} clickable={false} />
            <% end %>
            <%= if @game.nominated_suit do %>
              <div class="mt-2 text-center">
                <span class="bg-white px-2 py-1 rounded">
                  Suit: <%= @game.nominated_suit %>
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Game Status -->
        <%= if @game.pending_attack do %>
          <div class="text-center mb-4">
            <span class="bg-red-600 text-white px-4 py-2 rounded-lg">
              Attack pending: <%= attack_description(@game.pending_attack) %>
            </span>
          </div>
        <% end %>

        <%= if @game.pending_skips > 0 do %>
          <div class="text-center mb-4">
            <span class="bg-yellow-600 text-white px-4 py-2 rounded-lg">
              Skips pending: <%= @game.pending_skips %>
            </span>
          </div>
        <% end %>

        <!-- Current Player's Hand -->
        <%= if @current_player do %>
          <div class="player-hand bg-white/20 rounded-lg p-4">
            <div class="text-white text-center mb-4">Your Hand</div>
            <div class="flex flex-wrap justify-center gap-2">
              <%= for card <- @current_player.hand do %>
                <.card_display 
                  card={card} 
                  clickable={true}
                  selected={card in @selected_cards}
                  phx-click="toggle_card"
                  phx-value-suit={card.suit}
                  phx-value-rank={card.rank}
                />
              <% end %>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="flex justify-center gap-4 mt-6">
            <%= if length(@selected_cards) > 0 do %>
              <%= if needs_suit_nomination?(@selected_cards) do %>
                <div class="flex gap-2">
                  <button 
                    phx-click="play_cards" 
                    phx-value-suit="hearts"
                    class="bg-red-600 hover:bg-red-700 text-white px-6 py-3 rounded-lg"
                  >
                    Play (♥)
                  </button>
                  <button 
                    phx-click="play_cards" 
                    phx-value-suit="diamonds"
                    class="bg-red-600 hover:bg-red-700 text-white px-6 py-3 rounded-lg"
                  >
                    Play (♦)
                  </button>
                  <button 
                    phx-click="play_cards" 
                    phx-value-suit="clubs"
                    class="bg-gray-800 hover:bg-gray-900 text-white px-6 py-3 rounded-lg"
                  >
                    Play (♣)
                  </button>
                  <button 
                    phx-click="play_cards" 
                    phx-value-suit="spades"
                    class="bg-gray-800 hover:bg-gray-900 text-white px-6 py-3 rounded-lg"
                  >
                    Play (♠)
                  </button>
                </div>
              <% else %>
                <button 
                  phx-click="play_cards" 
                  class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg text-lg"
                >
                  Play Selected Cards
                </button>
              <% end %>
            <% end %>

            <button 
              phx-click="draw_card" 
              class="bg-yellow-600 hover:bg-yellow-700 text-white px-8 py-3 rounded-lg text-lg"
            >
              <%= draw_button_text(@game) %>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def card_display(assigns) do
    assigns = assign_new(assigns, :selected, fn -> false end)
    
    ~H"""
    <div 
      class={[
        "card w-20 h-28 bg-white rounded-lg border-2 flex flex-col items-center justify-center",
        @clickable && "cursor-pointer",
        "transition-all shadow-lg",
        @clickable && "hover:scale-105",
        @selected && "ring-4 ring-blue-500 scale-110",
        card_color_class(@card)
      ]}
      {@rest}
    >
      <span class="text-3xl font-bold"><%= rank_display(@card) %></span>
      <span class="text-4xl"><%= suit_symbol(@card) %></span>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_card", %{"suit" => suit, "rank" => rank}, socket) do
    rank = String.to_integer(rank)
    suit = String.to_existing_atom(suit)
    card = Card.new(suit, rank)

    selected_cards =
      if card in socket.assigns.selected_cards do
        List.delete(socket.assigns.selected_cards, card)
      else
        socket.assigns.selected_cards ++ [card]
      end

    {:noreply, assign(socket, :selected_cards, selected_cards)}
  end

  @impl true
  def handle_event("play_cards", params, socket) do
    nominated_suit = Map.get(params, "suit") |> maybe_to_atom()
    
    case GameManager.play_cards(
           socket.assigns.game_id,
           socket.assigns.current_player.id,
           socket.assigns.selected_cards,
           nominated_suit
         ) do
      {:ok, _game} ->
        {:noreply, assign(socket, :selected_cards, [])}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  @impl true
  def handle_event("draw_card", _params, socket) do
    reason =
      if socket.assigns.game.pending_attack do
        :attack
      else
        :cannot_play
      end

    case GameManager.draw_cards(
           socket.assigns.game_id,
           socket.assigns.current_player.id,
           reason
         ) do
      {:ok, _game} ->
        {:noreply, assign(socket, :selected_cards, [])}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  @impl true
  def handle_info({_event, game}, socket) do
    {:noreply,
     socket
     |> assign(:game, game)
     |> assign(:current_player, current_player(game))}
  end

  # Helper functions

  defp current_player(game) do
    Enum.at(game.players, game.current_player_index)
  end

  defp current_player_name(game) do
    player = current_player(game)
    if player, do: player.name, else: "Unknown"
  end

  defp card_color_class(%Card{suit: suit}) when suit in [:hearts, :diamonds] do
    "text-red-600"
  end

  defp card_color_class(_), do: "text-gray-900"

  defp rank_display(%Card{rank: 11}), do: "J"
  defp rank_display(%Card{rank: 12}), do: "Q"
  defp rank_display(%Card{rank: 13}), do: "K"
  defp rank_display(%Card{rank: 14}), do: "A"
  defp rank_display(%Card{rank: rank}), do: to_string(rank)

  defp suit_symbol(%Card{suit: :hearts}), do: "♥"
  defp suit_symbol(%Card{suit: :diamonds}), do: "♦"
  defp suit_symbol(%Card{suit: :clubs}), do: "♣"
  defp suit_symbol(%Card{suit: :spades}), do: "♠"

  defp needs_suit_nomination?(cards) do
    Enum.any?(cards, fn card -> card.rank == 14 end)
  end

  defp attack_description({:twos, count}), do: "Draw #{count}"
  defp attack_description({:black_jacks, count}), do: "Draw #{count}"

  defp draw_button_text(%{pending_attack: nil}), do: "Draw Card"
  defp draw_button_text(%{pending_attack: {_, count}}), do: "Draw #{count} Cards"

  defp error_message(:not_your_turn), do: "It's not your turn"
  defp error_message(:invalid_play), do: "Invalid card play"
  defp error_message(:cards_not_in_hand), do: "Selected cards not in hand"
  defp error_message(other), do: "Error: #{inspect(other)}"

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp maybe_to_atom(val), do: val
end