defmodule RachelWeb.AnalyticsLive do
  @moduledoc """
  Analytics dashboard for viewing game statistics and metrics.

  Displays comprehensive game analytics including win rates, card usage,
  player behavior, and performance metrics.
  """

  use RachelWeb, :live_view
  alias Rachel.Analytics

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Load analytics data when connected
      socket =
        socket
        |> assign(:loading, false)
        |> load_overview_stats()
        |> load_card_stats()
        |> load_player_stats()
        |> load_performance_stats()
        |> assign(:active_tab, "overview")

      {:ok, socket}
    else
      {:ok, assign(socket, loading: true, active_tab: "overview")}
    end
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/analytics?tab=#{tab}")}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> load_overview_stats()
      |> load_card_stats()
      |> load_player_stats()
      |> load_performance_stats()

    {:noreply, put_flash(socket, :info, "Analytics refreshed")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="analytics-dashboard">
      <div class="header">
        <h1>Game Analytics Dashboard</h1>
        <button phx-click="refresh" class="refresh-button">
          Refresh Data
        </button>
      </div>

      <div class="tabs">
        <button
          class={tab_class("overview", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="overview"
        >
          Overview
        </button>
        <button
          class={tab_class("cards", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="cards"
        >
          Card Statistics
        </button>
        <button
          class={tab_class("players", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="players"
        >
          Player Behavior
        </button>
        <button
          class={tab_class("performance", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="performance"
        >
          Performance
        </button>
      </div>

      <div class="tab-content">
        <%= case @active_tab do %>
          <% "overview" -> %>
            <%= render_overview(assigns) %>
          <% "cards" -> %>
            <%= render_cards(assigns) %>
          <% "players" -> %>
            <%= render_players(assigns) %>
          <% "performance" -> %>
            <%= render_performance(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_overview(assigns) do
    ~H"""
    <div class="overview-stats">
      <h2>Overview</h2>

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value"><%= @total_games_7d %></div>
          <div class="stat-label">Games (Last 7 Days)</div>
        </div>

        <div class="stat-card">
          <div class="stat-value"><%= @total_games_30d %></div>
          <div class="stat-label">Games (Last 30 Days)</div>
        </div>

        <div class="stat-card">
          <div class="stat-value"><%= format_percentage(@abandoned_rate) %></div>
          <div class="stat-label">Abandoned Game Rate</div>
        </div>
      </div>

      <div class="chart-section">
        <h3>Win Rate by Player Type</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Player Type</th>
              <th>Wins</th>
              <th>Win %</th>
            </tr>
          </thead>
          <tbody>
            <%= for stat <- @win_rates do %>
              <tr>
                <td><%= format_player_type(stat.winner_type) %></td>
                <td><%= stat.wins %></td>
                <td><%= format_percentage(stat.win_percentage) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="chart-section">
        <h3>Peak Play Times (Last 30 Days)</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Hour (UTC)</th>
              <th>Games Started</th>
              <th>Unique Days</th>
            </tr>
          </thead>
          <tbody>
            <%= for time_stat <- @peak_times do %>
              <tr>
                <td><%= format_hour(time_stat.hour_of_day) %></td>
                <td><%= time_stat.games_started %></td>
                <td><%= time_stat.unique_days %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_cards(assigns) do
    ~H"""
    <div class="card-stats">
      <h2>Card Statistics</h2>

      <div class="chart-section">
        <h3>Most Played Cards</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Cards</th>
              <th>Times Played</th>
              <th>Led to Wins</th>
              <th>Win Rate %</th>
            </tr>
          </thead>
          <tbody>
            <%= for card_stat <- @most_played_cards do %>
              <tr>
                <td><%= format_cards(card_stat.cards) %></td>
                <td><%= card_stat.times_played %></td>
                <td><%= card_stat.led_to_wins || 0 %></td>
                <td><%= format_percentage(card_stat.win_rate_percentage) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="chart-section">
        <h3>Card Stacking Frequency</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Stack Size</th>
              <th>Occurrences</th>
              <th>Percentage</th>
            </tr>
          </thead>
          <tbody>
            <%= for stack_stat <- @stacking_frequency do %>
              <tr>
                <td><%= stack_stat.stack_size %> cards</td>
                <td><%= stack_stat.occurrences %></td>
                <td><%= format_percentage(stack_stat.percentage) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="chart-section">
        <h3>Draw Reasons Distribution</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Reason</th>
              <th>Attack Type</th>
              <th>Total Cards Drawn</th>
              <th>Occurrences</th>
              <th>Avg per Draw</th>
            </tr>
          </thead>
          <tbody>
            <%= for draw_stat <- @draw_reasons do %>
              <tr>
                <td><%= format_draw_reason(draw_stat.reason) %></td>
                <td><%= draw_stat.attack_type || "-" %></td>
                <td><%= draw_stat.total_cards_drawn %></td>
                <td><%= draw_stat.occurrences %></td>
                <td><%= draw_stat.avg_cards_per_draw %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_players(assigns) do
    ~H"""
    <div class="player-stats">
      <h2>Player Behavior</h2>

      <div class="chart-section">
        <h3>AI Difficulty Effectiveness</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Difficulty</th>
              <th>Wins</th>
              <th>Avg Turns to Win</th>
              <th>Avg Duration (s)</th>
            </tr>
          </thead>
          <tbody>
            <%= for ai_stat <- @ai_effectiveness do %>
              <tr>
                <td><%= String.capitalize(ai_stat.difficulty) %></td>
                <td><%= ai_stat.wins %></td>
                <td><%= ai_stat.avg_turns_to_win %></td>
                <td><%= ai_stat.avg_duration_seconds %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_performance(assigns) do
    ~H"""
    <div class="performance-stats">
      <h2>Performance Metrics</h2>

      <div class="chart-section">
        <h3>Average Game Metrics by Player Count</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Players</th>
              <th>Games Played</th>
              <th>Avg Duration (s)</th>
              <th>Avg Turns</th>
              <th>Avg Turns/Player</th>
            </tr>
          </thead>
          <tbody>
            <%= for metric <- @game_metrics do %>
              <tr>
                <td><%= metric.player_count %></td>
                <td><%= metric.games_played %></td>
                <td><%= metric.avg_duration_seconds %></td>
                <td><%= metric.avg_turns %></td>
                <td><%= metric.avg_turns_per_player %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Data loading functions

  defp load_overview_stats(socket) do
    socket
    |> assign(:total_games_7d, Analytics.total_games_played(days: 7))
    |> assign(:total_games_30d, Analytics.total_games_played(days: 30))
    |> assign(:win_rates, Analytics.win_rates_by_player_type())
    |> assign(:peak_times, Analytics.peak_play_times())
    |> assign(:abandoned_rate, get_abandoned_rate())
  end

  defp load_card_stats(socket) do
    socket
    |> assign(:most_played_cards, Analytics.most_played_cards(20))
    |> assign(:stacking_frequency, Analytics.card_stacking_frequency())
    |> assign(:draw_reasons, Analytics.draw_reasons_distribution())
  end

  defp load_player_stats(socket) do
    socket
    |> assign(:ai_effectiveness, Analytics.ai_difficulty_effectiveness())
  end

  defp load_performance_stats(socket) do
    socket
    |> assign(:game_metrics, Analytics.avg_game_metrics_by_player_count())
  end

  defp get_abandoned_rate do
    case Analytics.abandoned_game_rate() do
      %{abandoned_rate: rate} -> rate
      _ -> 0.0
    end
  end

  # Formatting helpers

  defp tab_class(tab, active_tab) do
    if tab == active_tab, do: "tab active", else: "tab"
  end

  defp format_percentage(nil), do: "0%"
  defp format_percentage(value) when is_float(value) or is_integer(value) do
    "#{:erlang.float_to_binary(value * 1.0, decimals: 1)}%"
  end

  defp format_player_type("ai"), do: "AI"
  defp format_player_type("user"), do: "User"
  defp format_player_type("anonymous"), do: "Anonymous"
  defp format_player_type(type), do: String.capitalize(to_string(type))

  defp format_hour(hour) when is_float(hour) or is_integer(hour) do
    hour = trunc(hour)
    "#{String.pad_leading(Integer.to_string(hour), 2, "0")}:00"
  end

  defp format_cards(cards) when is_map(cards) do
    # Handle JSONB map format
    cards
    |> Jason.encode!()
    |> String.replace("\"", "")
  end

  defp format_draw_reason("cannot_play"), do: "Cannot Play"
  defp format_draw_reason("attack_penalty"), do: "Attack Penalty"
  defp format_draw_reason("voluntary"), do: "Voluntary"
  defp format_draw_reason(reason), do: String.capitalize(to_string(reason))
end
