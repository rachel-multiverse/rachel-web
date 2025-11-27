defmodule RachelWeb.LeaderboardLive do
  use RachelWeb, :live_view

  alias Rachel.Leaderboard

  @tier_colors %{
    "bronze" => "bg-amber-700",
    "silver" => "bg-gray-400",
    "gold" => "bg-yellow-500",
    "platinum" => "bg-cyan-400",
    "diamond" => "bg-purple-500"
  }

  @tier_icons %{
    "bronze" => "🥉",
    "silver" => "🥈",
    "gold" => "🥇",
    "platinum" => "💎",
    "diamond" => "👑"
  }

  @impl true
  def mount(_params, session, socket) do
    current_user = get_authenticated_user(session, socket)
    leaderboard = Leaderboard.get_leaderboard(limit: 100)
    user_rank = Leaderboard.get_user_rank(current_user.id)
    recent_history = Leaderboard.get_rating_history(current_user.id, limit: 5)

    {:ok,
     assign(socket,
       page_title: "Leaderboard",
       current_user: current_user,
       leaderboard: leaderboard,
       user_rank: user_rank,
       recent_history: recent_history,
       tier_colors: @tier_colors,
       tier_icons: @tier_icons
     )}
  end

  defp get_authenticated_user(session, socket) do
    case session["user_token"] do
      nil ->
        case Map.get(socket.assigns, :current_scope) do
          %{user: user} -> user
          _ -> Map.get(socket.assigns, :user) || raise "No authenticated user found"
        end

      token ->
        case Rachel.Accounts.get_user_by_session_token(token) do
          {user, _authenticated_at} -> user
          user -> user
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-900 via-green-800 to-green-900 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-xl p-6 mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Leaderboard</h1>
          <p class="text-gray-600 mt-1">Top Rachel players ranked by Elo rating</p>
        </div>
        
    <!-- Tier Legend -->
        <div class="bg-white rounded-lg shadow-xl p-4 mb-6">
          <h2 class="text-sm font-semibold text-gray-700 mb-2">Tiers</h2>
          <div class="flex flex-wrap gap-3">
            <.tier_badge tier="diamond" icons={@tier_icons} colors={@tier_colors} label="1500+" />
            <.tier_badge tier="platinum" icons={@tier_icons} colors={@tier_colors} label="1300-1499" />
            <.tier_badge tier="gold" icons={@tier_icons} colors={@tier_colors} label="1100-1299" />
            <.tier_badge tier="silver" icons={@tier_icons} colors={@tier_colors} label="900-1099" />
            <.tier_badge tier="bronze" icons={@tier_icons} colors={@tier_colors} label="<900" />
          </div>
        </div>
        
    <!-- Your Rank Card -->
        <%= if @current_user.elo_games_played > 0 do %>
          <div class="bg-white rounded-lg shadow-xl p-6 mb-6 border-2 border-yellow-400">
            <h2 class="text-lg font-semibold text-gray-700 mb-3">Your Rank</h2>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <span class="text-3xl font-bold text-gray-900">#{@user_rank || "—"}</span>
                <div>
                  <div class="font-semibold">
                    {@current_user.display_name || @current_user.username}
                  </div>
                  <div class="text-sm text-gray-600">
                    {@current_user.elo_games_played} ranked games
                  </div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-2xl font-bold">{@current_user.elo_rating}</div>
                <div class={"inline-flex items-center px-2 py-1 rounded text-white text-sm #{@tier_colors[@current_user.elo_tier]}"}>
                  {@tier_icons[@current_user.elo_tier]} {String.capitalize(@current_user.elo_tier)}
                </div>
              </div>
            </div>
            
    <!-- Recent trend -->
            <%= if @recent_history != [] do %>
              <div class="mt-4 pt-4 border-t">
                <div class="text-sm text-gray-600">Recent:</div>
                <div class="flex gap-2 mt-1">
                  <%= for entry <- Enum.take(@recent_history, 5) do %>
                    <span class={
                      if entry.rating_change >= 0, do: "text-green-600", else: "text-red-600"
                    }>
                      {if entry.rating_change >= 0, do: "+", else: ""}{entry.rating_change}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="bg-white rounded-lg shadow-xl p-6 mb-6 border-2 border-gray-300">
            <h2 class="text-lg font-semibold text-gray-700 mb-2">Your Rank</h2>
            <p class="text-gray-600">
              Play ranked games against other humans to appear on the leaderboard!
            </p>
            <.link
              href={~p"/lobby"}
              class="inline-block mt-3 bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
            >
              Find a Game
            </.link>
          </div>
        <% end %>
        
    <!-- Leaderboard Table -->
        <div class="bg-white rounded-lg shadow-xl overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Rank</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Player</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Tier</th>
                <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Rating</th>
                <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Games</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= if @leaderboard == [] do %>
                <tr>
                  <td colspan="5" class="px-4 py-8 text-center text-gray-500">
                    No ranked players yet. Be the first!
                  </td>
                </tr>
              <% else %>
                <%= for {player, idx} <- Enum.with_index(@leaderboard, 1) do %>
                  <tr class={if player.id == @current_user.id, do: "bg-yellow-50", else: ""}>
                    <td class="px-4 py-3">
                      <span class={rank_class(idx)}>{idx}</span>
                    </td>
                    <td class="px-4 py-3">
                      <div class="font-medium">{player.display_name || player.username}</div>
                    </td>
                    <td class="px-4 py-3">
                      <span class={"inline-flex items-center px-2 py-1 rounded text-white text-xs #{@tier_colors[player.elo_tier]}"}>
                        {@tier_icons[player.elo_tier]} {String.capitalize(player.elo_tier)}
                      </span>
                    </td>
                    <td class="px-4 py-3 text-right font-semibold">{player.elo_rating}</td>
                    <td class="px-4 py-3 text-right text-gray-600">{player.elo_games_played}</td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp tier_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <span class={"w-3 h-3 rounded-full #{@colors[@tier]}"}></span>
      <span class="text-sm">{@icons[@tier]} {String.capitalize(@tier)}</span>
      <span class="text-xs text-gray-500">({@label})</span>
    </div>
    """
  end

  defp rank_class(1), do: "text-xl font-bold text-yellow-500"
  defp rank_class(2), do: "text-lg font-bold text-gray-400"
  defp rank_class(3), do: "text-lg font-bold text-amber-600"
  defp rank_class(_), do: "text-gray-700"
end
