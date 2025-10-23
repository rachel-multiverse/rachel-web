defmodule RachelWeb.HistoryLive do
  use RachelWeb, :live_view
  alias Rachel.Game.Games

  @impl true
  def mount(_params, session, socket) do
    # Get user from session (set by fetch_current_user plug)
    user =
      case session["user_token"] do
        nil ->
          # In tests, get from assigns
          Map.get(socket.assigns, :user) || raise "No authenticated user found"

        token ->
          # In production, fetch from database using session token
          # get_user_by_session_token returns {user, authenticated_at} tuple
          case Rachel.Accounts.get_user_by_session_token(token) do
            {user, _authenticated_at} -> user
            user -> user
          end
      end

    games = Games.list_user_games(user.id, limit: 50)

    {:ok,
     assign(socket,
       page_title: "Game History",
       user: user,
       games: games
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-900 via-green-800 to-green-900 py-8 px-4">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-xl p-6 mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Game History</h1>
              <p class="text-gray-600 mt-1">
                View your past games and performance
              </p>
            </div>
            <div class="flex gap-3">
              <.link href={~p"/stats"} class="btn btn-primary btn-soft">
                View Stats
              </.link>
              <.link href={~p"/lobby"} class="btn btn-primary">
                Play Now
              </.link>
            </div>
          </div>
        </div>

        <!-- Games List -->
        <%= if Enum.empty?(@games) do %>
          <div class="bg-white rounded-lg shadow-lg p-12 text-center">
            <div class="mb-4">
              <svg class="w-24 h-24 mx-auto text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-900 mb-2">No Game History Yet</h3>
            <p class="text-gray-600 mb-6">
              Start playing to build your game history!
            </p>
            <.link href={~p"/lobby"} class="btn btn-primary">
              Play Your First Game
            </.link>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for game <- @games do %>
              <div class="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
                <div class="flex items-start justify-between">
                  <!-- Game Info -->
                  <div class="flex-1">
                    <div class="flex items-center gap-3 mb-3">
                      <!-- Result Badge -->
                      <span class={[
                        "px-3 py-1 rounded-full text-sm font-semibold",
                        if(@user.username in game.winners, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800")
                      ]}>
                        <%= if @user.username in game.winners do %>
                          🏆 Victory
                        <% else %>
                          <%= ordinal(game.user_rank) %> Place
                        <% end %>
                      </span>

                      <!-- Player Count -->
                      <span class="text-sm text-gray-600">
                        <%= game.player_count %> Players
                      </span>

                      <!-- Date -->
                      <span class="text-sm text-gray-500">
                        <%= relative_time(game.finished_at) %>
                      </span>
                    </div>

                    <!-- Players List -->
                    <div class="flex items-center gap-2 mb-3">
                      <span class="text-sm font-medium text-gray-700">Players:</span>
                      <div class="flex flex-wrap gap-2">
                        <%= for player <- game.players do %>
                          <span class={[
                            "px-2 py-1 rounded text-xs font-medium",
                            if(player["name"] == @user.username, do: "bg-blue-100 text-blue-800", else: "bg-gray-100 text-gray-700")
                          ]}>
                            <%= player["name"] %>
                            <%= if player["name"] in game.winners do %>
                              <span class="ml-1">👑</span>
                            <% end %>
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <!-- Stats Row -->
                    <div class="flex gap-6 text-sm">
                      <div>
                        <span class="text-gray-600">Your Turns:</span>
                        <span class="font-semibold text-gray-900 ml-1">
                          <%= game.user_turns %>
                        </span>
                      </div>
                      <div>
                        <span class="text-gray-600">Total Turns:</span>
                        <span class="font-semibold text-gray-900 ml-1">
                          <%= game.turn_count %>
                        </span>
                      </div>
                      <div>
                        <span class="text-gray-600">Position:</span>
                        <span class="font-semibold text-gray-900 ml-1">
                          <%= ordinal(game.user_position + 1) %>
                        </span>
                      </div>
                    </div>
                  </div>

                  <!-- Game ID (for debugging) -->
                  <div class="text-xs text-gray-400 font-mono">
                    #<%= String.slice(game.id, 0..7) %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Load More (if we implement pagination) -->
          <%= if length(@games) >= 50 do %>
            <div class="mt-6 text-center">
              <p class="text-gray-600">
                Showing your 50 most recent games
              </p>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp ordinal(n) when n in [11, 12, 13], do: "#{n}th"
  defp ordinal(n) when rem(n, 10) == 1, do: "#{n}st"
  defp ordinal(n) when rem(n, 10) == 2, do: "#{n}nd"
  defp ordinal(n) when rem(n, 10) == 3, do: "#{n}rd"
  defp ordinal(n), do: "#{n}th"

  defp relative_time(datetime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds_ago < 60 -> "Just now"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      seconds_ago < 86_400 -> "#{div(seconds_ago, 3600)}h ago"
      seconds_ago < 604_800 -> "#{div(seconds_ago, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
