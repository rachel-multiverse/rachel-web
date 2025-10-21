defmodule RachelWeb.UserRegistrationLive do
  use RachelWeb, :live_view

  alias Rachel.Accounts
  alias Rachel.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-800 to-green-900 flex items-center justify-center p-4">
      <div class="max-w-md w-full bg-white rounded-lg shadow-xl p-8">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">Join Rachel</h1>
          <p class="text-gray-600">Create your account to start playing</p>
        </div>

        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-6"
        >
          <div>
            <.input field={@form[:email]} type="email" label="Email" required />
          </div>

          <div>
            <.input field={@form[:username]} type="text" label="Username" required />
          </div>

          <div>
            <.input field={@form[:password]} type="password" label="Password" required />
          </div>

          <div>
            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-4 rounded-lg transition duration-200"
            >
              Create Account
            </button>
          </div>
        </.form>

        <div class="mt-6 text-center">
          <p class="text-sm text-gray-600">
            Already have an account?
            <.link
              navigate={~p"/users/log_in"}
              class="font-semibold text-green-600 hover:text-green-700"
            >
              Log in
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
