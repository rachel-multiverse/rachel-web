defmodule RachelWeb.ReconnectableLive do
  @moduledoc """
  Provides reconnection support for LiveView games.
  Include this module in your LiveView to get automatic reconnection handling.
  """

  defmacro __using__(_opts) do
    quote do
      alias Rachel.Game.{SessionManager, ConnectionMonitor}
      
      @heartbeat_interval_ms 5_000  # Send heartbeat every 5 seconds
      
      # Mount callback with reconnection support
      def mount_with_reconnection(params, session, socket) do
        socket = 
          socket
          |> assign(:session_token, nil)
          |> assign(:reconnecting, false)
          |> assign(:connection_status, :connecting)
        
        # Check for existing session token in session storage
        case get_session_token(session) do
          nil ->
            # New connection, proceed normally
            {:ok, socket}
          
          session_token ->
            # Attempt to reconnect with existing session
            handle_reconnection_attempt(socket, session_token)
        end
      end
      
      # Handle reconnection attempt
      defp handle_reconnection_attempt(socket, session_token) do
        case ConnectionMonitor.handle_reconnect(session_token, self()) do
          {:ok, session} ->
            # Successful reconnection
            socket = 
              socket
              |> assign(:session_token, session_token)
              |> assign(:game_id, session.game_id)
              |> assign(:player_id, session.player_id)
              |> assign(:player_name, session.player_name)
              |> assign(:reconnecting, false)
              |> assign(:connection_status, :connected)
              |> put_flash(:info, "Reconnected to game!")
            
            # Rejoin the game
            GameEngine.subscribe(session.game_id)
            
            # Start heartbeat
            Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
            
            # Load current game state
            case GameEngine.get_state(session.game_id) do
              {:ok, game} ->
                {:ok, assign(socket, :game, game)}
              
              _ ->
                {:ok, 
                 socket
                 |> put_flash(:error, "Game no longer exists")
                 |> redirect(to: ~p"/")}
            end
          
          {:error, :invalid_session} ->
            # Session doesn't exist
            {:ok, 
             socket
             |> assign(:session_token, nil)
             |> assign(:reconnecting, false)}
          
          {:error, :session_expired} ->
            # Session expired
            {:ok,
             socket
             |> assign(:session_token, nil)
             |> assign(:reconnecting, false)
             |> put_flash(:error, "Your session has expired. Please start a new game.")}
        end
      end
      
      # Create a new session when joining a game
      def create_game_session(socket, game_id, player_id, player_name) do
        case SessionManager.create_session(game_id, player_id, player_name) do
          {:ok, session_token} ->
            # Start monitoring
            ConnectionMonitor.monitor_player(session_token, self())
            
            # Save session token
            socket = 
              socket
              |> assign(:session_token, session_token)
              |> assign(:connection_status, :connected)
            
            # Start heartbeat
            Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
            
            {:ok, socket}
          
          error ->
            {:error, socket, error}
        end
      end
      
      # Handle heartbeat
      def handle_info(:heartbeat, socket) do
        if socket.assigns[:session_token] do
          ConnectionMonitor.heartbeat(socket.assigns.session_token)
          Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
        end
        
        {:noreply, socket}
      end
      
      # Handle connection status updates
      def handle_info({:player_status, player_id, status}, socket) do
        # Update UI to show player connection status
        socket = 
          if player_id == socket.assigns[:player_id] do
            assign(socket, :connection_status, status)
          else
            # Update other player's status in game state
            update_player_connection_status(socket, player_id, status)
          end
        
        {:noreply, socket}
      end
      
      # Handle Phoenix LiveView disconnect/reconnect
      def handle_info(%Phoenix.Socket.Broadcast{event: "disconnect"}, socket) do
        if socket.assigns[:session_token] do
          ConnectionMonitor.handle_disconnect(socket.assigns.session_token)
        end
        
        {:noreply, assign(socket, :connection_status, :disconnected)}
      end
      
      def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
        # Handle presence changes if using Phoenix Presence
        {:noreply, socket}
      end
      
      # Clean up on termination
      def terminate(_reason, socket) do
        if socket.assigns[:session_token] do
          ConnectionMonitor.unmonitor_player(socket.assigns.session_token)
        end
        
        :ok
      end
      
      # Helper to get session token from session storage
      defp get_session_token(session) do
        Map.get(session, "session_token")
      end
      
      # Helper to update player connection status in UI
      defp update_player_connection_status(socket, player_id, status) do
        case socket.assigns[:game] do
          nil ->
            socket
          
          game ->
            # Update the player's connection status in the game state for UI
            players = 
              Enum.map(game.players, fn player ->
                if player.id == player_id do
                  Map.put(player, :connection_status, status)
                else
                  player
                end
              end)
            
            updated_game = Map.put(game, :players, players)
            assign(socket, :game, updated_game)
        end
      end
      
      # Override these as needed
      defoverridable [
        mount_with_reconnection: 3,
        handle_reconnection_attempt: 2,
        create_game_session: 4,
        get_session_token: 1,
        update_player_connection_status: 3
      ]
    end
  end
end