defmodule RachelWeb.AdminLive do
  @moduledoc """
  Administrative dashboard for managing the Rachel platform.

  Provides interfaces for:
  - System analytics and metrics
  - Content moderation
  - User management
  - System overview
  """

  use RachelWeb, :live_view
  alias Rachel.{Analytics, Accounts, Moderation.ModerationService}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      socket =
        socket
        |> assign(:loading, false)
        |> assign(:active_tab, "overview")
        |> load_overview_data()

      {:ok, socket}
    else
      {:ok, assign(socket, loading: true, active_tab: "overview")}
    end
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> load_tab_data(tab)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-dashboard">
      <div class="header">
        <div>
          <h1>Admin Dashboard</h1>
          <p class="subtitle">Platform administration and moderation</p>
        </div>
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
          class={tab_class("analytics", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="analytics"
        >
          Analytics
        </button>
        <button
          class={tab_class("moderation", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="moderation"
        >
          Moderation
          <%= if @pending_flags_count > 0 do %>
            <span class="badge"><%= @pending_flags_count %></span>
          <% end %>
        </button>
        <button
          class={tab_class("users", @active_tab)}
          phx-click="change_tab"
          phx-value-tab="users"
        >
          Users
        </button>
      </div>

      <div class="tab-content">
        <%= case @active_tab do %>
          <% "overview" -> %>
            <%= render_overview(assigns) %>
          <% "analytics" -> %>
            <%= render_analytics(assigns) %>
          <% "moderation" -> %>
            <%= render_moderation(assigns) %>
          <% "users" -> %>
            <%= render_users(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_overview(assigns) do
    ~H"""
    <div class="overview-section">
      <h2>System Overview</h2>

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value"><%= @total_users %></div>
          <div class="stat-label">Total Users</div>
        </div>

        <div class="stat-card">
          <div class="stat-value"><%= @active_users_24h %></div>
          <div class="stat-label">Active (24h)</div>
        </div>

        <div class="stat-card">
          <div class="stat-value"><%= @total_games_7d %></div>
          <div class="stat-label">Games (7 days)</div>
        </div>

        <div class="stat-card">
          <div class="stat-value"><%= @pending_flags_count %></div>
          <div class="stat-label">Pending Flags</div>
        </div>
      </div>

      <div class="chart-section">
        <h3>Recent Activity</h3>
        <p class="text-muted">Quick overview of platform activity in the last 7 days</p>
        <table class="stats-table">
          <tbody>
            <tr>
              <td>New Users</td>
              <td class="text-right"><%= @new_users_7d %></td>
            </tr>
            <tr>
              <td>Games Played</td>
              <td class="text-right"><%= @total_games_7d %></td>
            </tr>
            <tr>
              <td>Moderation Flags</td>
              <td class="text-right"><%= @flags_7d %></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_analytics(assigns) do
    ~H"""
    <div class="analytics-section">
      <h2>Game Analytics</h2>
      <p class="text-muted">Comprehensive game statistics and player behavior</p>
      <p class="info-box">
        📊 <strong>Note:</strong> For detailed analytics, visit the
        <a href="/analytics" class="link">dedicated analytics dashboard</a>
      </p>

      <div class="chart-section">
        <h3>Quick Stats (Last 30 Days)</h3>
        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-value"><%= @total_games_30d %></div>
            <div class="stat-label">Total Games</div>
          </div>
          <div class="stat-card">
            <div class="stat-value"><%= format_percentage(@abandoned_rate) %></div>
            <div class="stat-label">Abandoned Rate</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_moderation(assigns) do
    ~H"""
    <div class="moderation-section">
      <h2>Content Moderation</h2>

      <div class="moderation-filters">
        <button class="filter-button active">Pending (<%= @pending_flags_count %>)</button>
        <button class="filter-button">Approved</button>
        <button class="filter-button">Rejected</button>
      </div>

      <%= if @pending_flags_count == 0 do %>
        <div class="empty-state">
          <p>✅ No pending moderation flags</p>
          <p class="text-muted">All content has been reviewed</p>
        </div>
      <% else %>
        <div class="moderation-queue">
          <%= for flag <- @moderation_flags do %>
            <div class="moderation-card">
              <div class="moderation-header">
                <div>
                  <strong><%= flag.user.display_name || flag.user.username %></strong>
                  <span class="text-muted">@<%= flag.user.username %></span>
                </div>
                <span class="badge badge-warning"><%= flag.status %></span>
              </div>

              <div class="moderation-content">
                <div class="field-name">Field: <code><%= flag.field_name %></code></div>
                <div class="flagged-content">
                  "<%= flag.flagged_content %>"
                </div>
                <div class="flag-reason">
                  <strong>Reason:</strong> <%= flag.reason %>
                </div>
              </div>

              <div class="moderation-meta">
                <small class="text-muted">
                  Flagged <%= relative_time(flag.inserted_at) %>
                </small>
              </div>

              <div class="moderation-actions">
                <button
                  phx-click="approve_flag"
                  phx-value-id={flag.id}
                  class="btn btn-success"
                >
                  Approve
                </button>
                <button
                  phx-click="reject_flag"
                  phx-value-id={flag.id}
                  class="btn btn-danger"
                >
                  Reject
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_users(assigns) do
    ~H"""
    <div class="users-section">
      <h2>User Management</h2>

      <div class="chart-section">
        <h3>Recent Users</h3>
        <table class="stats-table">
          <thead>
            <tr>
              <th>Username</th>
              <th>Email</th>
              <th>Games</th>
              <th>Win Rate</th>
              <th>Joined</th>
              <th>Admin</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for user <- @recent_users do %>
              <tr>
                <td><%= user.display_name || user.username %></td>
                <td><%= user.email %></td>
                <td><%= user.games_played %></td>
                <td><%= format_win_rate(user.games_played, user.games_won) %></td>
                <td><%= format_date(user.inserted_at) %></td>
                <td>
                  <%= if user.is_admin do %>
                    <span class="badge badge-admin">Admin</span>
                  <% end %>
                </td>
                <td>
                  <%= if !user.is_admin do %>
                    <button
                      phx-click="toggle_admin"
                      phx-value-user-id={user.id}
                      class="btn btn-sm"
                    >
                      Make Admin
                    </button>
                  <% else %>
                    <button
                      phx-click="toggle_admin"
                      phx-value-user-id={user.id}
                      class="btn btn-sm btn-secondary"
                    >
                      Remove Admin
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Data loading functions

  defp load_overview_data(socket) do
    socket
    |> assign(:total_users, Accounts.count_users())
    |> assign(:active_users_24h, Accounts.count_active_users(hours: 24))
    |> assign(:new_users_7d, Accounts.count_new_users(days: 7))
    |> assign(:total_games_7d, Analytics.total_games_played(days: 7))
    |> assign(:total_games_30d, Analytics.total_games_played(days: 30))
    |> assign(:abandoned_rate, get_abandoned_rate())
    |> assign(:pending_flags_count, ModerationService.count_pending_flags())
    |> assign(:flags_7d, ModerationService.count_flags(days: 7))
    |> assign(:moderation_flags, [])
    |> assign(:recent_users, [])
  end

  defp load_tab_data(socket, "overview") do
    load_overview_data(socket)
  end

  defp load_tab_data(socket, "analytics") do
    socket
    |> assign(:total_games_30d, Analytics.total_games_played(days: 30))
    |> assign(:abandoned_rate, get_abandoned_rate())
  end

  defp load_tab_data(socket, "moderation") do
    socket
    |> assign(:moderation_flags, ModerationService.list_pending_flags())
    |> assign(:pending_flags_count, ModerationService.count_pending_flags())
  end

  defp load_tab_data(socket, "users") do
    socket
    |> assign(:recent_users, Accounts.list_recent_users(limit: 50))
  end

  defp load_tab_data(socket, _tab), do: socket

  defp get_abandoned_rate do
    case Analytics.abandoned_game_rate() do
      %{abandoned_rate: rate} -> rate
      _ -> 0.0
    end
  end

  # Event handlers

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin?tab=#{tab}")}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> load_tab_data(socket.assigns.active_tab)
      |> put_flash(:info, "Data refreshed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("approve_flag", %{"id" => flag_id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case ModerationService.review_flag(flag_id, current_user_id, :approved) do
      {:ok, _flag} ->
        socket =
          socket
          |> load_tab_data("moderation")
          |> put_flash(:info, "Content approved")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve content")}
    end
  end

  @impl true
  def handle_event("reject_flag", %{"id" => flag_id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case ModerationService.review_flag(flag_id, current_user_id, :rejected) do
      {:ok, _flag} ->
        socket =
          socket
          |> load_tab_data("moderation")
          |> put_flash(:info, "Content rejected")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reject content")}
    end
  end

  @impl true
  def handle_event("toggle_admin", %{"user-id" => user_id}, socket) do
    case Accounts.toggle_admin_status(user_id) do
      {:ok, user} ->
        action = if user.is_admin, do: "granted", else: "revoked"

        socket =
          socket
          |> load_tab_data("users")
          |> put_flash(:info, "Admin privileges #{action}")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update admin status")}
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

  defp format_win_rate(0, _wins), do: "N/A"

  defp format_win_rate(games_played, games_won) do
    rate = games_won / games_played * 100
    "#{:erlang.float_to_binary(rate, decimals: 1)}%"
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end

  defp relative_time(datetime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds_ago < 60 -> "just now"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)} minutes ago"
      seconds_ago < 86_400 -> "#{div(seconds_ago, 3600)} hours ago"
      true -> "#{div(seconds_ago, 86_400)} days ago"
    end
  end
end
