defmodule RachelWeb.ProfileLive do
  use RachelWeb, :live_view
  alias Rachel.Accounts
  alias Rachel.Game.AvatarLibrary

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

    avatars = AvatarLibrary.list_avatars()
    categories = AvatarLibrary.list_categories()

    changeset = Accounts.User.profile_changeset(user, %{})

    {:ok,
     socket
     |> assign(:page_title, "Profile Settings")
     |> assign(:user, user)
     |> assign(:avatars, avatars)
     |> assign(:categories, categories)
     |> assign(:selected_category, "faces")
     |> assign(:form, to_form(changeset, as: :profile))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_avatar", %{"avatar-id" => avatar_id}, socket) do
    {avatar_id, _} = Integer.parse(avatar_id)
    changeset = Accounts.User.profile_changeset(socket.assigns.user, %{avatar_id: avatar_id})
    {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.user, profile_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> put_flash(:info, "Profile updated successfully")
         |> push_patch(to: ~p"/settings")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Profile Settings</h1>

      <.form
        for={@form}
        as={:profile}
        id="profile-form"
        phx-submit="save"
        class="space-y-8"
      >
        <!-- Avatar Selection -->
        <section class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Choose Avatar</h2>

          <!-- Category Filter -->
          <div class="flex gap-2 mb-4">
            <%= for category <- @categories do %>
              <button
                type="button"
                phx-click="filter_category"
                phx-value-category={category}
                class={"px-4 py-2 rounded-lg transition-colors " <>
                  if(@selected_category == category, do: "bg-green-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")}
              >
                <%= String.capitalize(category) %>
              </button>
            <% end %>
          </div>

          <!-- Avatar Grid -->
          <div class="grid grid-cols-6 md:grid-cols-10 gap-3">
            <%= for avatar <- Enum.filter(@avatars, &(&1.category == @selected_category)) do %>
              <button
                type="button"
                phx-click="select_avatar"
                phx-value-avatar-id={avatar.id}
                class={"avatar-option text-4xl p-3 rounded-lg border-2 transition-all hover:scale-110 " <>
                  if(@form.params["avatar_id"] == avatar.id, do: "border-green-600 bg-green-50", else: "border-gray-300 hover:border-green-400")}
                title={avatar.name}
              >
                <%= avatar.character %>
              </button>
            <% end %>
          </div>
        </section>

        <!-- Personal Info -->
        <section class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Personal Information</h2>

          <.input field={@form[:display_name]} type="text" label="Display Name" required />
          <.input field={@form[:tagline]} type="text" label="Tagline" placeholder="Your motto or catchphrase (50 chars max)" />
          <.input field={@form[:bio]} type="textarea" label="Bio" placeholder="Tell us about yourself (250 chars max)" rows="4" />
        </section>

        <!-- Game Preferences -->
        <section class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Game Preferences</h2>

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">AI Difficulty</label>
              <select name="profile[preferences][gameplay][ai_difficulty]" class="select select-bordered w-full">
                <option value="easy">Easy</option>
                <option value="medium" selected>Medium</option>
                <option value="hard">Hard</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Animation Speed</label>
              <select name="profile[preferences][visual][animation_speed]" class="select select-bordered w-full">
                <option value="slow">Slow</option>
                <option value="normal" selected>Normal</option>
                <option value="fast">Fast</option>
              </select>
            </div>

            <div class="flex items-center gap-3">
              <input type="checkbox" name="profile[preferences][gameplay][show_hints]" checked class="checkbox" />
              <label class="text-sm font-medium text-gray-700">Show gameplay hints</label>
            </div>
          </div>
        </section>

        <!-- Save Button -->
        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </.form>
    </div>
    """
  end
end
