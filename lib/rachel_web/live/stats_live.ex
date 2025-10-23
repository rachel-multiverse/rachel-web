defmodule RachelWeb.StatsLive do
  use RachelWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    # Get user from session (set by fetch_current_user plug)
    user =
      case session["user_token"] do
        nil ->
          # In tests, get from assigns
          case Map.get(socket.assigns, :current_scope) do
            %{user: user} -> user
            _ -> Map.get(socket.assigns, :user) || raise "No authenticated user found"
          end

        token ->
          # In production, fetch from database using session token
          case Rachel.Accounts.get_user_by_session_token(token) do
            {user, _authenticated_at} -> user
            user -> user
          end
      end

    # Calculate derived statistics
    win_rate = calculate_win_rate(user.games_won, user.games_played)
    avg_turns_per_game = calculate_avg_turns(user.total_turns, user.games_played)
    loss_count = user.games_played - user.games_won

    {:ok,
     assign(socket,
       page_title: "Statistics",
       user: user,
       win_rate: win_rate,
       avg_turns_per_game: avg_turns_per_game,
       loss_count: loss_count
     )}
  end

  defp calculate_win_rate(wins, total_games) when total_games > 0 do
    Float.round(wins / total_games * 100, 1)
  end

  defp calculate_win_rate(_wins, _total_games), do: 0.0

  defp calculate_avg_turns(total_turns, total_games) when total_games > 0 do
    Float.round(total_turns / total_games, 1)
  end

  defp calculate_avg_turns(_total_turns, _total_games), do: 0.0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-900 via-green-800 to-green-900 py-8 px-4">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-xl p-6 mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">
                {@user.display_name || @user.username}'s Statistics
              </h1>
              <p class="text-gray-600 mt-1">Track your Rachel game performance</p>
            </div>
            <.link
              href={~p"/lobby"}
              class="btn btn-primary"
            >
              Play Now
            </.link>
          </div>
        </div>

        <!-- Main Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <!-- Games Played -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-gray-600 text-sm font-medium">Games Played</p>
                <p class="text-4xl font-bold text-gray-900 mt-2">{@user.games_played}</p>
              </div>
              <div class="bg-blue-100 rounded-full p-3">
                <svg
                  class="w-8 h-8 text-blue-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M14 10l-2 1m0 0l-2-1m2 1v2.5M20 7l-2 1m2-1l-2-1m2 1v2.5M14 4l-2-1-2 1M4 7l2-1M4 7l2 1M4 7v2.5M12 21l-2-1m2 1l2-1m-2 1v-2.5M6 18l-2-1v-2.5M18 18l2-1v-2.5"
                  />
                </svg>
              </div>
            </div>
          </div>

          <!-- Games Won -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-gray-600 text-sm font-medium">Games Won</p>
                <p class="text-4xl font-bold text-green-600 mt-2">{@user.games_won}</p>
              </div>
              <div class="bg-green-100 rounded-full p-3">
                <svg
                  class="w-8 h-8 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
            </div>
          </div>

          <!-- Win Rate -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-gray-600 text-sm font-medium">Win Rate</p>
                <p class="text-4xl font-bold text-purple-600 mt-2">{@win_rate}%</p>
              </div>
              <div class="bg-purple-100 rounded-full p-3">
                <svg
                  class="w-8 h-8 text-purple-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
                  />
                </svg>
              </div>
            </div>
          </div>

          <!-- Total Turns -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-gray-600 text-sm font-medium">Total Turns</p>
                <p class="text-4xl font-bold text-orange-600 mt-2">{@user.total_turns}</p>
              </div>
              <div class="bg-orange-100 rounded-full p-3">
                <svg
                  class="w-8 h-8 text-orange-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>

        <!-- Detailed Stats -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Performance Overview -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h2 class="text-xl font-bold text-gray-900 mb-4">Performance Overview</h2>
            <div class="space-y-4">
              <!-- Win/Loss Bar -->
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span class="text-gray-600">Wins vs Losses</span>
                  <span class="text-gray-900 font-medium">
                    {@user.games_won}W - {@loss_count}L
                  </span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-4 overflow-hidden">
                  <div
                    class="bg-gradient-to-r from-green-500 to-green-600 h-4 transition-all duration-500"
                    style={"width: #{@win_rate}%"}
                  >
                  </div>
                </div>
              </div>

              <!-- Average Turns per Game -->
              <div class="flex justify-between items-center py-3 border-b">
                <span class="text-gray-600">Avg. Turns per Game</span>
                <span class="text-xl font-bold text-gray-900">{@avg_turns_per_game}</span>
              </div>

              <!-- Games Played -->
              <div class="flex justify-between items-center py-3 border-b">
                <span class="text-gray-600">Total Games</span>
                <span class="text-xl font-bold text-gray-900">{@user.games_played}</span>
              </div>

              <!-- Best Streak (placeholder for future) -->
              <div class="flex justify-between items-center py-3">
                <span class="text-gray-600">Best Win Streak</span>
                <span class="text-xl font-bold text-gray-400">Coming Soon</span>
              </div>
            </div>
          </div>

          <!-- Quick Stats -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h2 class="text-xl font-bold text-gray-900 mb-4">Quick Facts</h2>
            <div class="space-y-3">
              <div class="bg-blue-50 rounded-lg p-4">
                <p class="text-sm text-blue-600 font-medium mb-1">Experience Level</p>
                <p class="text-2xl font-bold text-blue-900">{experience_level(@user.games_played)}</p>
              </div>

              <div class="bg-green-50 rounded-lg p-4">
                <p class="text-sm text-green-600 font-medium mb-1">Win Rank</p>
                <p class="text-2xl font-bold text-green-900">{win_rank(@win_rate)}</p>
              </div>

              <div class="bg-purple-50 rounded-lg p-4">
                <p class="text-sm text-purple-600 font-medium mb-1">Member Since</p>
                <p class="text-2xl font-bold text-purple-900">
                  {Calendar.strftime(@user.inserted_at, "%B %Y")}
                </p>
              </div>

              <div class="bg-orange-50 rounded-lg p-4">
                <p class="text-sm text-orange-600 font-medium mb-1">Last Active</p>
                <p class="text-lg font-bold text-orange-900">
                  {if @user.last_seen_at, do: relative_time(@user.last_seen_at), else: "Unknown"}
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Call to Action -->
        <%= if @user.games_played == 0 do %>
          <div class="mt-6 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-lg shadow-lg p-8 text-center">
            <h3 class="text-2xl font-bold text-white mb-2">Ready to Start Your Journey?</h3>
            <p class="text-yellow-100 mb-4">Play your first game and start building your stats!</p>
            <.link href={~p"/lobby"} class="btn bg-white text-orange-600 hover:bg-yellow-50">
              Play First Game
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp experience_level(games_played) when games_played >= 100, do: "Expert 🏆"
  defp experience_level(games_played) when games_played >= 50, do: "Veteran ⭐"
  defp experience_level(games_played) when games_played >= 25, do: "Experienced 💪"
  defp experience_level(games_played) when games_played >= 10, do: "Regular 🎮"
  defp experience_level(games_played) when games_played >= 5, do: "Beginner 🌱"
  defp experience_level(_games_played), do: "Newbie 🐣"

  defp win_rank(win_rate) when win_rate >= 70, do: "Master 🥇"
  defp win_rank(win_rate) when win_rate >= 60, do: "Pro 🥈"
  defp win_rank(win_rate) when win_rate >= 50, do: "Skilled 🥉"
  defp win_rank(win_rate) when win_rate >= 40, do: "Average 📊"
  defp win_rank(win_rate) when win_rate >= 30, do: "Learning 📚"
  defp win_rank(_win_rate), do: "Rookie 🎓"

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
