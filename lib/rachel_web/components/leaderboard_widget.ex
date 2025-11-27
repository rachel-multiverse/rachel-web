defmodule RachelWeb.Components.LeaderboardWidget do
  use Phoenix.Component

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

  attr :current_user, :map, required: true

  def leaderboard_widget(assigns) do
    top_players = Leaderboard.get_leaderboard(limit: 5)
    user_rank = Leaderboard.get_user_rank(assigns.current_user.id)

    assigns =
      assigns
      |> assign(:top_players, top_players)
      |> assign(:user_rank, user_rank)
      |> assign(:tier_colors, @tier_colors)
      |> assign(:tier_icons, @tier_icons)

    ~H"""
    <div class="bg-white rounded-lg shadow-lg p-4">
      <div class="flex justify-between items-center mb-3">
        <h3 class="font-bold text-gray-900">Top Players</h3>
        <a href="/leaderboard" class="text-sm text-green-600 hover:text-green-700">
          View Full Leaderboard →
        </a>
      </div>

      <%= if @top_players == [] do %>
        <p class="text-gray-500 text-sm">No ranked players yet!</p>
      <% else %>
        <div class="space-y-2">
          <%= for {player, idx} <- Enum.with_index(@top_players, 1) do %>
            <div class={"flex items-center justify-between py-1 #{if player.id == @current_user.id, do: "bg-yellow-50 -mx-2 px-2 rounded", else: ""}"}>
              <div class="flex items-center gap-2">
                <span class={"w-5 text-center font-bold #{rank_color(idx)}"}>{idx}</span>
                <span class="text-sm">{player.display_name || player.username}</span>
              </div>
              <div class="flex items-center gap-2">
                <span class={"text-xs px-1 rounded #{@tier_colors[player.elo_tier]} text-white"}>
                  {@tier_icons[player.elo_tier]}
                </span>
                <span class="text-sm font-semibold">{player.elo_rating}</span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Current user's rank if not in top 5 -->
      <%= if @user_rank && @user_rank > 5 do %>
        <div class="mt-3 pt-3 border-t">
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-600">Your rank:</span>
            <span class="font-bold">#{@user_rank}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp rank_color(1), do: "text-yellow-500"
  defp rank_color(2), do: "text-gray-400"
  defp rank_color(3), do: "text-amber-600"
  defp rank_color(_), do: "text-gray-600"
end
