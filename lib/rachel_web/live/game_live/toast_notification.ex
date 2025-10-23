defmodule RachelWeb.GameLive.ToastNotification do
  @moduledoc """
  Toast notification component for displaying temporary success/error messages during gameplay.
  Automatically dismisses after a few seconds.
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div
      id="toast-container"
      class="fixed top-20 right-4 z-50 flex flex-col gap-2 pointer-events-none"
      phx-hook="ToastNotifications"
    >
      <!-- Success Toast -->
      <%= if @flash["info"] do %>
        <div
          id="toast-info"
          class="toast-notification toast-success pointer-events-auto transform transition-all duration-300 ease-out"
          role="alert"
          phx-mounted={show_toast()}
          phx-click={hide_toast("info")}
        >
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <svg
                class="w-5 h-5 text-green-400"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-white">{@flash["info"]}</p>
            </div>
            <button
              type="button"
              class="flex-shrink-0 text-white/70 hover:text-white transition-colors"
              aria-label="Dismiss"
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>
        </div>
      <% end %>
      <!-- Error Toast -->
      <%= if @flash["error"] do %>
        <div
          id="toast-error"
          class="toast-notification toast-error pointer-events-auto transform transition-all duration-300 ease-out"
          role="alert"
          phx-mounted={show_toast()}
          phx-click={hide_toast("error")}
        >
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <svg
                class="w-5 h-5 text-red-400"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-white">{@flash["error"]}</p>
            </div>
            <button
              type="button"
              class="flex-shrink-0 text-white/70 hover:text-white transition-colors"
              aria-label="Dismiss"
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>
        </div>
      <% end %>
      <!-- Warning Toast -->
      <%= if @flash["warning"] do %>
        <div
          id="toast-warning"
          class="toast-notification toast-warning pointer-events-auto transform transition-all duration-300 ease-out"
          role="alert"
          phx-mounted={show_toast()}
          phx-click={hide_toast("warning")}
        >
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <svg
                class="w-5 h-5 text-yellow-400"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-white">{@flash["warning"]}</p>
            </div>
            <button
              type="button"
              class="flex-shrink-0 text-white/70 hover:text-white transition-colors"
              aria-label="Dismiss"
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # JavaScript commands for showing/hiding toasts
  defp show_toast do
    Phoenix.LiveView.JS.add_class("toast-enter",
      transition:
        {"ease-out duration-300", "opacity-0 translate-x-full", "opacity-100 translate-x-0"}
    )
  end

  defp hide_toast(kind) do
    Phoenix.LiveView.JS.push("lv:clear-flash", value: %{key: kind})
    |> Phoenix.LiveView.JS.hide(
      to: "#toast-#{kind}",
      transition:
        {"ease-in duration-200", "opacity-100 translate-x-0", "opacity-0 translate-x-full"}
    )
  end
end
