defmodule RachelWeb.UserLoginLive do
  use RachelWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-900 flex items-center justify-center p-4">
      <div class="max-w-md w-full bg-white rounded-lg shadow-xl p-8">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">Welcome Back</h1>
          <p class="text-gray-600">Log in to continue playing</p>
        </div>

        <.form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="space-y-6">
          <div>
            <.input field={@form[:email]} type="email" label="Email" required />
          </div>

          <div>
            <.input field={@form[:password]} type="password" label="Password" required />
          </div>

          <div class="flex items-center">
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          </div>

          <div>
            <button
              type="submit"
              class="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-4 rounded-lg transition duration-200"
            >
              Log in
            </button>
          </div>
        </.form>

        <div class="mt-6 text-center space-y-2">
          <p class="text-sm text-gray-600">
            Don't have an account?
            <.link
              navigate={~p"/users/register"}
              class="font-semibold text-green-600 hover:text-green-700"
            >
              Sign up
            </.link>
          </p>
          <p class="text-sm text-gray-600">
            <.link
              navigate={~p"/users/reset_password"}
              class="font-semibold text-green-600 hover:text-green-700"
            >
              Forgot your password?
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
