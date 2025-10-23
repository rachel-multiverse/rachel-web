defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.Game.Card
  alias Rachel.GameManager
  alias RachelWeb.GameLive.{GameHelpers, ViewHelpers}

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
    <div class="game-container min-h-screen bg-green-900 p-4" id="game-sounds" phx-hook="GameSounds">
      <!-- Connection Status Indicator -->
      <div
        id="connection-status"
        phx-hook="ConnectionStatus"
        class="fixed top-4 right-4 z-50 bg-white rounded-lg px-3 py-2 shadow-lg"
      >
        <span class="status-text text-sm font-medium">🟢 Connected</span>
      </div>

    <!-- Session Persistence -->
      <div id="session-persistence" phx-hook="SessionPersistence" class="hidden"></div>
      <div id="auto-reconnect" phx-hook="AutoReconnect" class="hidden"></div>
      <div id="turn-transition" phx-hook="TurnTransition" class="hidden"></div>

      <!-- Toast Notifications -->
      <.live_component module={RachelWeb.GameLive.ToastNotification} id="toast-notifications" flash={@flash} />

      <div class="max-w-7xl mx-auto">
        
    <!-- Game Over Screen -->
        <%= if @game.status == :finished do %>
          <.live_component module={RachelWeb.GameLive.GameOverModal} id="game-over-modal" game={@game} />
        <% end %>
        <!-- Game Header and Play Area -->
        <.live_component
          module={RachelWeb.GameLive.GameBoard}
          id="game-board"
          game={@game}
          is_your_turn={@game.current_player_index == 0}
          current_player_name={current_player_name(@game)}
          direction_symbol={direction_symbol(@game.direction)}
          attack_description={attack_description(@game.pending_attack)}
        />

    <!-- Other Players (Always show AI players 1, 2, 3) -->
        <.live_component module={RachelWeb.GameLive.OpponentHands} id="opponent-hands" game={@game} />
        
    <!-- Your Hand (Always Show Only Yours) -->
        <%= if @game.players && length(@game.players) > 0 do %>
          <% you = Enum.at(@game.players, 0) %>
          <%= if you && you.type == :human do %>
            <.live_component
              module={RachelWeb.GameLive.PlayerHand}
              id="player-hand"
              game={@game}
              player={you}
              selected_cards={@selected_cards}
              is_your_turn={@game.current_player_index == 0}
              button_text={smart_button_text(@game, you)}
            />
          <% end %>
        <% end %>
        
    <!-- Suit Selection Modal -->
        <%= if @show_suit_modal do %>
          <.live_component module={RachelWeb.GameLive.SuitModal} id="suit-modal" />
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
        "card w-20 h-28 bg-white rounded-lg border-2 flex flex-col items-center justify-center shadow-lg",
        @clickable && "cursor-pointer",
        @selected && "ring-4 ring-blue-500",
        @playable && "ring-2 ring-green-400",
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
      if card_playable?(socket.assigns.game, card, socket.assigns.selected_cards) do
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
          {:noreply,
           socket
           |> assign(:selected_cards, [])
           |> push_event("card-played", %{cards: socket.assigns.selected_cards, player: human_player.id})}

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
         |> assign(:show_suit_modal, false)
         |> push_event("card-played", %{cards: socket.assigns.selected_cards, player: human_player.id})}

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
        {:ok, game} ->
          # Calculate how many cards were drawn
          cards_drawn = length(Enum.at(game.players, 0).hand) - length(human_player.hand)

          {:noreply,
           socket
           |> assign(:selected_cards, [])
           |> push_event("cards-drawn", %{count: cards_drawn})}

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
  def handle_event("new_game", _params, socket) do
    # Redirect to lobby to start a new game
    {:noreply, redirect(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({_event, game}, socket) do
    old_game = socket.assigns.game
    is_your_turn = game.current_player_index == 0
    was_your_turn = old_game.current_player_index == 0

    # Detect turn change
    turn_changed = is_your_turn && !was_your_turn

    # Detect game over
    game_just_ended = game.status == :finished && old_game.status != :finished

    socket =
      socket
      |> assign(:game, game)
      |> assign(:current_player, current_player(game))
      |> assign(:show_suit_modal, false)

    # Push turn change event
    socket =
      if turn_changed do
        push_event(socket, "turn-changed", %{isYourTurn: true})
      else
        socket
      end

    # Push game-over event with winner info
    socket =
      if game_just_ended do
        human_player = Enum.at(game.players, 0)
        first_winner = List.first(game.winners)
        is_winner = human_player.id == first_winner

        push_event(socket, "game-over", %{
          winner: first_winner,
          isWinner: is_winner
        })
      else
        socket
      end

    {:noreply, socket}
  end

  # Helper functions - delegated to modules

  defdelegate current_player(game), to: GameHelpers
  defdelegate current_player_name(game), to: GameHelpers
  defdelegate card_color_class(card), to: ViewHelpers
  defdelegate rank_display(card), to: ViewHelpers
  defdelegate suit_symbol(card), to: ViewHelpers
  defdelegate direction_symbol(direction), to: ViewHelpers
  defdelegate needs_suit_nomination?(cards), to: GameHelpers
  defdelegate attack_description(attack), to: ViewHelpers
  defdelegate draw_button_text(game), to: ViewHelpers
  defdelegate has_valid_plays?(game, player), to: GameHelpers
  defdelegate smart_button_text(game, player), to: GameHelpers

  # Use renamed function without 'is_' prefix
  defp card_playable?(game, card, selected_cards) do
    GameHelpers.card_playable?(game, card, selected_cards)
  end

  defdelegate error_message(error), to: ViewHelpers

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp maybe_to_atom(val), do: val
end
