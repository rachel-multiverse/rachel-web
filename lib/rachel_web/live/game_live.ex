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
         |> assign(:nominated_suit, nil)
         |> assign(:show_suit_modal, false)}

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
            <h1 class="text-2xl font-bold">Rachel Game</h1>
            <div class="flex gap-4">
              <span class="text-sm">Turn: {@game.turn_count}</span>
              <span class="text-sm">
                Current Player: {current_player_name(@game)}
              </span>
              <span class="text-sm flex items-center gap-1">
                Direction: {direction_symbol(@game.direction)}
              </span>
            </div>
          </div>
        </div>
        
    <!-- Other Players (Always show AI players 1, 2, 3) -->
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
        
    <!-- Game Status -->
        <%= if @game.pending_attack do %>
          <div class="text-center mb-4">
            <span class="bg-red-600 text-white px-4 py-2 rounded-lg">
              Attack pending: {attack_description(@game.pending_attack)}
            </span>
          </div>
        <% end %>

        <%= if @game.pending_skips > 0 do %>
          <div class="text-center mb-4">
            <span class="bg-yellow-600 text-white px-4 py-2 rounded-lg">
              Skips pending: {@game.pending_skips}
            </span>
          </div>
        <% end %>
        
    <!-- Your Hand (Always Show Only Yours) -->
        <%= if @game.players && length(@game.players) > 0 do %>
          <% you = Enum.at(@game.players, 0) %>
          <%= if you && you.type == :human do %>
            <div class="player-hand bg-white/20 rounded-lg p-4">
              <div class="text-white text-center mb-4">
                Your Hand
                <%= if @game.current_player_index == 0 do %>
                  <span class="text-yellow-400 text-sm ml-2">← Your Turn</span>
                <% end %>
              </div>
              <div class="flex flex-wrap justify-center gap-2">
                <%= for card <- you.hand do %>
                  <% is_playable =
                    @game.current_player_index == 0 &&
                      (card in @selected_cards || is_card_playable?(@game, card, @selected_cards)) %>
                  <.card_display
                    card={card}
                    clickable={is_playable}
                    selected={card in @selected_cards}
                    playable={
                      @game.current_player_index == 0 &&
                        is_card_playable?(@game, card, @selected_cards)
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
            <%= if @game.current_player_index == 0 do %>
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
                    {smart_button_text(@game, you)}
                  </button>
                <% end %>
              </div>
            <% end %>
          <% end %>
        <% end %>
        
    <!-- Suit Selection Modal -->
        <%= if @show_suit_modal do %>
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
        <% end %>
      </div>
    </div>
    """
  end

  attr :card, :any, required: true
  attr :clickable, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :playable, :boolean, default: false
  attr :in_hand, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-suit phx-value-rank)

  def card_display(assigns) do
    ~H"""
    <div
      class={[
        "card w-20 h-28 bg-white rounded-lg border-2 flex flex-col items-center justify-center",
        @clickable && "cursor-pointer",
        "transition-all shadow-lg",
        @clickable && "hover:scale-105",
        @selected && "ring-4 ring-blue-500 scale-110",
        @playable && "ring-2 ring-green-400 shadow-green-300",
        @in_hand && !@clickable && !@selected && "opacity-50 grayscale",
        card_color_class(@card)
      ]}
      {@rest}
    >
      <span class="text-3xl font-bold">{rank_display(@card)}</span>
      <span class="text-4xl">{suit_symbol(@card)}</span>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_card", %{"suit" => suit, "rank" => rank}, socket) do
    rank = String.to_integer(rank)
    suit = String.to_existing_atom(suit)
    card = Card.new(suit, rank)

    if card in socket.assigns.selected_cards do
      # Always allow deselecting a card that's already selected
      selected_cards = List.delete(socket.assigns.selected_cards, card)
      {:noreply, assign(socket, :selected_cards, selected_cards)}
    else
      # Only allow selecting cards that are playable
      if is_card_playable?(socket.assigns.game, card, socket.assigns.selected_cards) do
        selected_cards = socket.assigns.selected_cards ++ [card]
        {:noreply, assign(socket, :selected_cards, selected_cards)}
      else
        # Card is not playable, show feedback and don't change selection
        {:noreply, put_flash(socket, :info, "That card cannot be played right now")}
      end
    end
  end

  @impl true
  def handle_event("attempt_play_cards", _params, socket) do
    if needs_suit_nomination?(socket.assigns.selected_cards) do
      # Show modal for suit selection
      {:noreply, assign(socket, :show_suit_modal, true)}
    else
      # Play cards directly
      human_player = Enum.at(socket.assigns.game.players, 0)

      case GameManager.play_cards(
             socket.assigns.game_id,
             human_player.id,
             socket.assigns.selected_cards,
             nil
           ) do
        {:ok, _game} ->
          {:noreply, assign(socket, :selected_cards, [])}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    end
  end

  @impl true
  def handle_event("play_cards", params, socket) do
    nominated_suit = Map.get(params, "suit") |> maybe_to_atom()

    # Always use the human player (index 0)
    human_player = Enum.at(socket.assigns.game.players, 0)

    case GameManager.play_cards(
           socket.assigns.game_id,
           human_player.id,
           socket.assigns.selected_cards,
           nominated_suit
         ) do
      {:ok, _game} ->
        {:noreply,
         socket
         |> assign(:selected_cards, [])
         |> assign(:show_suit_modal, false)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  @impl true
  def handle_event("close_suit_modal", _params, socket) do
    {:noreply, assign(socket, :show_suit_modal, false)}
  end

  @impl true
  def handle_event("draw_card", _params, socket) do
    # Always use the human player (index 0)
    human_player = Enum.at(socket.assigns.game.players, 0)

    reason =
      if socket.assigns.game.pending_attack do
        :attack
      else
        :cannot_play
      end

    # Mandatory play rule validation - only allow drawing if no valid plays
    can_draw =
      if socket.assigns.game.pending_attack do
        # Always can draw under attack
        true
      else
        # Check if player has any valid plays
        top_card = hd(socket.assigns.game.discard_pile)

        has_valid_play =
          Enum.any?(human_player.hand, fn card ->
            Rachel.Game.Rules.can_play_card?(card, top_card, socket.assigns.game.nominated_suit)
          end)

        # Can only draw if no valid plays
        not has_valid_play
      end

    if can_draw do
      case GameManager.draw_cards(
             socket.assigns.game_id,
             human_player.id,
             reason
           ) do
        {:ok, _game} ->
          {:noreply, assign(socket, :selected_cards, [])}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "You must play a card - drawing is not allowed when you have valid plays"
       )}
    end
  end

  @impl true
  def handle_info({_event, game}, socket) do
    {:noreply,
     socket
     |> assign(:game, game)
     |> assign(:current_player, current_player(game))
     |> assign(:show_suit_modal, false)}
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

  defp direction_symbol(:clockwise), do: "↻"
  defp direction_symbol(:counter_clockwise), do: "↺"

  defp needs_suit_nomination?(cards) do
    Enum.any?(cards, fn card -> card.rank == 14 end)
  end

  defp attack_description({:twos, count}), do: "Draw #{count}"
  defp attack_description({:black_jacks, count}), do: "Draw #{count}"

  defp draw_button_text(%{pending_attack: nil}), do: "Draw Card"
  defp draw_button_text(%{pending_attack: {_, count}}), do: "Draw #{count} Cards"

  defp smart_button_text(game, player) do
    cond do
      # Under attack - must draw
      game.pending_attack != nil ->
        draw_button_text(game)

      # Check if player has valid plays
      player && has_valid_plays?(game, player) ->
        "Select cards to play"

      # No valid plays - can draw
      true ->
        "Draw Card"
    end
  end

  defp has_valid_plays?(game, player) do
    top_card = hd(game.discard_pile)

    Enum.any?(player.hand, fn card ->
      Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
    end)
  end

  defp is_card_playable?(game, card, selected_cards) do
    cond do
      # If no cards selected, check basic playability
      Enum.empty?(selected_cards) ->
        is_card_playable_standalone?(game, card)

      # If cards already selected, check if this card can stack with them
      true ->
        can_stack_with_selected?(card, selected_cards)
    end
  end

  defp is_card_playable_standalone?(game, card) do
    cond do
      # Under attack - can only play counter cards
      game.pending_attack != nil ->
        {attack_type, _} = game.pending_attack
        Rachel.Game.Rules.can_counter_attack?(card, attack_type)

      # Normal play
      true ->
        top_card = hd(game.discard_pile)
        Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
    end
  end

  defp can_stack_with_selected?(card, selected_cards) do
    # Can only stack cards of the same rank
    first_selected = hd(selected_cards)
    card.rank == first_selected.rank
  end

  defp error_message(:not_your_turn), do: "It's not your turn"
  defp error_message(:invalid_play), do: "Invalid card play"
  defp error_message(:cards_not_in_hand), do: "Selected cards not in hand"
  defp error_message(other), do: "Error: #{inspect(other)}"

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp maybe_to_atom(val), do: val
end
