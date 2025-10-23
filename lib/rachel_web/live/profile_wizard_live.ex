defmodule RachelWeb.ProfileWizardLive do
  use RachelWeb, :live_view
  alias Rachel.Accounts
  alias Rachel.Game.AvatarLibrary

  @impl true
  def mount(_params, session, socket) do
    user = get_authenticated_user(session, socket)

    if user.profile_completed do
      {:ok, push_navigate(socket, to: ~p"/lobby")}
    else
      {:ok, setup_profile_wizard(socket, user)}
    end
  end

  defp get_authenticated_user(session, socket) do
    case session["user_token"] do
      nil -> get_user_from_assigns(socket)
      token -> get_user_from_token(token)
    end
  end

  defp get_user_from_assigns(socket) do
    case Map.get(socket.assigns, :current_scope) do
      %{user: user} -> user
      _ -> Map.get(socket.assigns, :user) || raise "No authenticated user found"
    end
  end

  defp get_user_from_token(token) do
    case Rachel.Accounts.get_user_by_session_token(token) do
      {user, _authenticated_at} -> user
      user -> user
    end
  end

  defp setup_profile_wizard(socket, user) do
    avatars = AvatarLibrary.list_avatars()
    default_avatar = AvatarLibrary.get_default_avatar()
    default_avatar_id = if default_avatar, do: default_avatar.id, else: nil

    socket
    |> assign(:page_title, "Complete Your Profile")
    |> assign(:user, user)
    |> assign(:avatars, avatars)
    |> assign(:selected_category, "faces")
    |> assign(:step, 1)
    |> assign(:profile_data, %{
      avatar_id: default_avatar_id,
      display_name: user.display_name || user.username,
      tagline: "",
      bio: "",
      preferences: %{}
    })
  end

  @impl true
  def handle_event("select_avatar", %{"avatar-id" => avatar_id}, socket) do
    {avatar_id, _} = Integer.parse(avatar_id)
    profile_data = Map.put(socket.assigns.profile_data, :avatar_id, avatar_id)
    {:noreply, assign(socket, :profile_data, profile_data)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step + 1)}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step - 1)}
  end

  @impl true
  def handle_event("update_profile", %{"profile" => profile_params}, socket) do
    # Convert string keys to atoms for consistent map structure
    atomized_params =
      profile_params
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Enum.into(%{})

    profile_data = Map.merge(socket.assigns.profile_data, atomized_params)

    {:noreply,
     assign(socket, :profile_data, profile_data) |> assign(:step, socket.assigns.step + 1)}
  end

  @impl true
  def handle_event("complete", _params, socket) do
    profile_data = Map.put(socket.assigns.profile_data, :profile_completed, true)

    case Accounts.update_user_profile(socket.assigns.user, profile_data) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile completed! Welcome to Rachel!")
         |> push_navigate(to: ~p"/lobby")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error completing profile")
         |> assign(:step, 2)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-green-900 flex items-center justify-center p-4">
      <div class="max-w-2xl w-full bg-white rounded-lg shadow-xl p-8">
        <!-- Progress Indicator -->
        <div class="mb-8">
          <p class="text-center text-sm text-gray-600 mb-2">Step {@step} of 3</p>
          <div class="flex gap-2">
            <%= for step <- 1..3 do %>
              <div class={"flex-1 h-2 rounded-full " <> if(step <= @step, do: "bg-green-600", else: "bg-gray-200")}>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Step Content -->
        <%= case @step do %>
          <% 1 -> %>
            {render_avatar_step(assigns)}
          <% 2 -> %>
            {render_personal_info_step(assigns)}
          <% 3 -> %>
            {render_preferences_step(assigns)}
        <% end %>
      </div>
    </div>
    """
  end

  defp render_avatar_step(assigns) do
    ~H"""
    <div>
      <h1 class="text-3xl font-bold text-center mb-2">Choose Your Avatar</h1>
      <p class="text-center text-gray-600 mb-6">Pick an emoji that represents you</p>
      
    <!-- Category Filter -->
      <div class="flex flex-wrap gap-2 justify-center mb-6">
        <%= for category <- AvatarLibrary.list_categories() do %>
          <button
            type="button"
            phx-click="filter_category"
            phx-value-category={category}
            class={"px-4 py-2 rounded-lg transition-colors text-sm " <>
              if(@selected_category == category, do: "bg-green-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")}
          >
            {String.capitalize(category)}
          </button>
        <% end %>
      </div>
      
    <!-- Avatar Grid -->
      <div class="grid grid-cols-5 md:grid-cols-8 gap-3 mb-8">
        <%= for avatar <- Enum.filter(@avatars, &(&1.category == @selected_category)) do %>
          <button
            type="button"
            phx-click="select_avatar"
            phx-value-avatar-id={avatar.id}
            class={"text-4xl p-3 rounded-lg border-2 transition-all hover:scale-110 " <>
              if(@profile_data.avatar_id == avatar.id, do: "border-green-600 bg-green-50 scale-110", else: "border-gray-300 hover:border-green-400")}
            title={avatar.name}
          >
            {avatar.character}
          </button>
        <% end %>
      </div>

      <div class="flex justify-end">
        <button type="button" phx-click="next_step" class="btn btn-primary">Next</button>
      </div>
    </div>
    """
  end

  defp render_personal_info_step(assigns) do
    ~H"""
    <div>
      <h1 class="text-3xl font-bold text-center mb-2">Personal Information</h1>
      <p class="text-center text-gray-600 mb-6">Tell us a bit about yourself</p>

      <.form
        for={%{}}
        as={:profile}
        id="wizard-form"
        phx-submit="update_profile"
        class="space-y-4"
      >
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
          <input
            type="text"
            name="profile[display_name]"
            value={@profile_data.display_name}
            class="input input-bordered w-full"
            required
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Tagline (optional)</label>
          <input
            type="text"
            name="profile[tagline]"
            value={@profile_data.tagline}
            placeholder="Your motto or catchphrase"
            maxlength="50"
            class="input input-bordered w-full"
          />
          <p class="text-xs text-gray-500 mt-1">Max 50 characters</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Bio (optional)</label>
          <textarea
            name="profile[bio]"
            placeholder="Tell us about yourself"
            maxlength="250"
            rows="3"
            class="textarea textarea-bordered w-full"
          ><%= @profile_data.bio %></textarea>
          <p class="text-xs text-gray-500 mt-1">Max 250 characters</p>
        </div>

        <div class="flex justify-between">
          <button type="button" phx-click="prev_step" class="btn btn-ghost">Back</button>
          <button type="submit" class="btn btn-primary">Next</button>
        </div>
      </.form>
    </div>
    """
  end

  defp render_preferences_step(assigns) do
    ~H"""
    <div>
      <h1 class="text-3xl font-bold text-center mb-2">Game Preferences</h1>
      <p class="text-center text-gray-600 mb-6">Customize your gaming experience</p>

      <div class="space-y-6 mb-8">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">AI Difficulty</label>
          <div class="flex gap-3">
            <%= for difficulty <- ["easy", "medium", "hard"] do %>
              <label class="flex-1">
                <input
                  type="radio"
                  name="ai_difficulty"
                  value={difficulty}
                  checked={difficulty == "medium"}
                  class="sr-only peer"
                />
                <div class="p-3 text-center border-2 rounded-lg cursor-pointer peer-checked:border-green-600 peer-checked:bg-green-50">
                  {String.capitalize(difficulty)}
                </div>
              </label>
            <% end %>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Animation Speed</label>
          <div class="flex gap-3">
            <%= for speed <- ["slow", "normal", "fast"] do %>
              <label class="flex-1">
                <input
                  type="radio"
                  name="animation_speed"
                  value={speed}
                  checked={speed == "normal"}
                  class="sr-only peer"
                />
                <div class="p-3 text-center border-2 rounded-lg cursor-pointer peer-checked:border-green-600 peer-checked:bg-green-50">
                  {String.capitalize(speed)}
                </div>
              </label>
            <% end %>
          </div>
        </div>

        <div class="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
          <input type="checkbox" id="show_hints" checked class="checkbox checkbox-primary" />
          <label for="show_hints" class="text-sm font-medium text-gray-700 cursor-pointer">
            Show gameplay hints and tips
          </label>
        </div>
      </div>

      <div class="flex justify-between">
        <button type="button" phx-click="prev_step" class="btn btn-ghost">Back</button>
        <button type="button" phx-click="complete" class="btn btn-primary">Complete Profile</button>
      </div>
    </div>
    """
  end
end
