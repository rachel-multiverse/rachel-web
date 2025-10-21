defmodule RachelWeb.UserResetPasswordLive do
  use RachelWeb, :live_view

  alias Rachel.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-900 flex items-center justify-center p-4">
      <div class="max-w-md w-full bg-white rounded-lg shadow-xl p-8">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Reset Password</h1>
          <p class="text-gray-600">Enter your email to receive reset instructions</p>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-6">
          <div>
            <.input field={@form[:email]} type="email" placeholder="Email" required />
          </div>

          <div>
            <button
              type="submit"
              class="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-4 rounded-lg transition duration-200"
            >
              Send reset instructions
            </button>
          </div>
        </.form>

        <div class="mt-6 text-center space-y-2">
          <p class="text-sm text-gray-600">
            <.link navigate={~p"/users/register"} class="font-semibold text-green-600 hover:text-green-700">
              Register
            </.link>
            |
            <.link navigate={~p"/users/log_in"} class="font-semibold text-green-600 hover:text-green-700">
              Log in
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
