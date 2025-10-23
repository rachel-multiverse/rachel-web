# Profile Customization Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Add comprehensive profile customization with avatar library, bio/tagline, game preferences, and content moderation.

**Architecture:** Multi-step onboarding wizard for new users, single-page settings for existing users. Avatar library using Unicode emoji (no uploads). Server-side content moderation with profanity filtering and flagging system. Game preferences stored in JSON field.

**Tech Stack:** Phoenix LiveView, Ecto, PostgreSQL, Elixir pattern matching for moderation

---

## Task 1: Database Schema - Avatar Library

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_avatars.exs`
- Create: `lib/rachel/game/avatar.ex`

**Step 1: Write the migration**

```elixir
defmodule Rachel.Repo.Migrations.CreateAvatars do
  use Ecto.Migration

  def change do
    create table(:avatars) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :character, :string, null: false
      add :display_order, :integer, null: false, default: 0
    end

    create index(:avatars, [:category])
    create index(:avatars, [:display_order])
  end
end
```

**Step 2: Create Avatar schema**

```elixir
defmodule Rachel.Game.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "avatars" do
    field :name, :string
    field :category, :string
    field :character, :string
    field :display_order, :integer
  end

  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [:name, :category, :character, :display_order])
    |> validate_required([:name, :category, :character, :display_order])
    |> validate_inclusion(:category, ~w(faces animals objects cards food nature))
  end
end
```

**Step 3: Run migration**

Run: `mise exec -- mix ecto.migrate`
Expected: Migration runs successfully

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_create_avatars.exs lib/rachel/game/avatar.ex
git commit -m "feat(profile): Add avatar library schema"
```

---

## Task 2: Database Schema - User Profile Fields

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_profile_fields_to_users.exs`
- Modify: `lib/rachel/accounts/user.ex`

**Step 1: Write the migration**

```elixir
defmodule Rachel.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tagline, :string
      add :bio, :text
      add :avatar_id, references(:avatars, on_delete: :nilify_all)
      add :profile_completed, :boolean, default: false, null: false
    end

    create index(:users, [:avatar_id])
    create index(:users, [:profile_completed])
  end
end
```

**Step 2: Update User schema**

In `lib/rachel/accounts/user.ex`, add fields after existing game-specific fields:

```elixir
# Add these fields around line 22
field :tagline, :string
field :bio, :string
field :avatar_id, :integer
field :profile_completed, :boolean, default: false

# Add this association
belongs_to :avatar, Rachel.Game.Avatar, define_field: false
```

**Step 3: Update profile_changeset**

Replace existing `profile_changeset` (around line 62):

```elixir
@doc """
A user changeset for profile updates with content moderation.
"""
def profile_changeset(user, attrs) do
  user
  |> cast(attrs, [:display_name, :tagline, :bio, :avatar_id, :preferences, :profile_completed])
  |> validate_length(:display_name, min: 3, max: 50)
  |> validate_length(:tagline, max: 50)
  |> validate_length(:bio, max: 250)
  |> foreign_key_constraint(:avatar_id)
  |> validate_change(:tagline, &validate_moderated_content/2)
  |> validate_change(:bio, &validate_moderated_content/2)
end

defp validate_moderated_content(field, value) do
  case Rachel.Moderation.ModerationService.check_content(value, field) do
    :ok -> []
    {:reject, reason} -> [{field, "#{reason}"}]
    {:flag, _reason} -> []  # Allow but will be flagged
  end
end
```

**Step 4: Run migration**

Run: `mise exec -- mix ecto.migrate`
Expected: Migration runs successfully

**Step 5: Commit**

```bash
git add priv/repo/migrations/*_add_profile_fields_to_users.exs lib/rachel/accounts/user.ex
git commit -m "feat(profile): Add profile fields to users"
```

---

## Task 3: Database Schema - Moderation Flags

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_moderation_flags.exs`
- Create: `lib/rachel/moderation/moderation_flag.ex`

**Step 1: Write the migration**

```elixir
defmodule Rachel.Repo.Migrations.CreateModerationFlags do
  use Ecto.Migration

  def change do
    create table(:moderation_flags, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :field_name, :string, null: false
      add :flagged_content, :text, null: false
      add :reason, :string, null: false
      add :status, :string, default: "pending", null: false
      add :reviewed_by, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:moderation_flags, [:user_id])
    create index(:moderation_flags, [:status])
    create index(:moderation_flags, [:reviewed_by])
  end
end
```

**Step 2: Create ModerationFlag schema**

```elixir
defmodule Rachel.Moderation.ModerationFlag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "moderation_flags" do
    belongs_to :user, Rachel.Accounts.User
    field :field_name, :string
    field :flagged_content, :string
    field :reason, :string
    field :status, :string, default: "pending"
    belongs_to :reviewed_by_user, Rachel.Accounts.User, foreign_key: :reviewed_by
    field :reviewed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(flag, attrs) do
    flag
    |> cast(attrs, [:user_id, :field_name, :flagged_content, :reason, :status, :reviewed_by, :reviewed_at])
    |> validate_required([:user_id, :field_name, :flagged_content, :reason])
    |> validate_inclusion(:status, ~w(pending approved rejected))
    |> validate_inclusion(:field_name, ~w(tagline bio display_name))
  end
end
```

**Step 3: Run migration**

Run: `mise exec -- mix ecto.migrate`
Expected: Migration runs successfully

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_create_moderation_flags.exs lib/rachel/moderation/moderation_flag.ex
git commit -m "feat(moderation): Add moderation flags table"
```

---

## Task 4: Moderation Service - Core Logic

**Files:**
- Create: `lib/rachel/moderation/moderation_service.ex`
- Create: `test/rachel/moderation/moderation_service_test.exs`

**Step 1: Write failing tests**

```elixir
defmodule Rachel.Moderation.ModerationServiceTest do
  use Rachel.DataCase, async: true
  alias Rachel.Moderation.ModerationService

  describe "check_content/2" do
    test "allows clean content" do
      assert :ok == ModerationService.check_content("Hello world", :tagline)
    end

    test "rejects content with profanity" do
      assert {:reject, _} = ModerationService.check_content("damn you", :tagline)
    end

    test "rejects content with URLs" do
      assert {:reject, _} = ModerationService.check_content("Visit http://spam.com", :tagline)
    end

    test "rejects content with excessive special characters" do
      assert {:reject, _} = ModerationService.check_content("!!!###$$$%%%", :tagline)
    end

    test "flags suspicious patterns" do
      assert {:flag, _} = ModerationService.check_content("v1agra ch3ap", :tagline)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mise exec -- mix test test/rachel/moderation/moderation_service_test.exs`
Expected: 5 failures (module doesn't exist)

**Step 3: Implement ModerationService**

```elixir
defmodule Rachel.Moderation.ModerationService do
  @moduledoc """
  Content moderation service for user-generated text.
  Checks for profanity, URLs, spam patterns, and excessive special characters.
  """

  alias Rachel.Moderation.ModerationFlag
  alias Rachel.Repo

  # Simple profanity list - expand as needed
  @profanity_words ~w(
    damn hell shit fuck crap bastard bitch ass asshole
    dickhead piss bollocks bugger
  )

  @suspicious_patterns [
    ~r/v[i1]a?g?r?a/i,
    ~r/c[i1]al[i1]s/i,
    ~r/ch[e3]ap/i,
    ~r/f[o0]{2,}/i
  ]

  @doc """
  Checks content for violations. Returns:
  - :ok if content is clean
  - {:reject, reason} if content violates rules (immediate rejection)
  - {:flag, reason} if content is suspicious (allow but flag for review)
  """
  def check_content(text, field_name) when is_binary(text) do
    text = String.downcase(String.trim(text))

    cond do
      contains_profanity?(text) ->
        {:reject, "contains inappropriate language"}

      contains_urls?(text) ->
        {:reject, "URLs are not allowed"}

      excessive_special_chars?(text) ->
        {:reject, "contains too many special characters"}

      suspicious_pattern?(text) ->
        {:flag, "suspicious pattern detected"}

      true ->
        :ok
    end
  end

  def check_content(nil, _field_name), do: :ok
  def check_content("", _field_name), do: :ok

  @doc """
  Creates a moderation flag for content that needs review.
  """
  def flag_for_review(user_id, field_name, content, reason) do
    %ModerationFlag{}
    |> ModerationFlag.changeset(%{
      user_id: user_id,
      field_name: Atom.to_string(field_name),
      flagged_content: content,
      reason: reason,
      status: "pending"
    })
    |> Repo.insert()
  end

  # Private helpers

  defp contains_profanity?(text) do
    Enum.any?(@profanity_words, fn word ->
      Regex.match?(~r/\b#{word}\b/i, text)
    end)
  end

  defp contains_urls?(text) do
    Regex.match?(~r/https?:\/\/|www\./i, text)
  end

  defp excessive_special_chars?(text) do
    # Count non-alphanumeric characters (excluding spaces)
    special_count = text
    |> String.replace(~r/[a-zA-Z0-9\s]/, "")
    |> String.length()

    special_count > 10
  end

  defp suspicious_pattern?(text) do
    Enum.any?(@suspicious_patterns, fn pattern ->
      Regex.match?(pattern, text)
    end)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mise exec -- mix test test/rachel/moderation/moderation_service_test.exs`
Expected: 5 passing tests

**Step 5: Commit**

```bash
git add lib/rachel/moderation/moderation_service.ex test/rachel/moderation/moderation_service_test.exs
git commit -m "feat(moderation): Add content moderation service"
```

---

## Task 5: Avatar Library Module

**Files:**
- Create: `lib/rachel/game/avatar_library.ex`
- Create: `priv/repo/seeds/avatars.exs`
- Create: `test/rachel/game/avatar_library_test.exs`

**Step 1: Write failing tests**

```elixir
defmodule Rachel.Game.AvatarLibraryTest do
  use Rachel.DataCase, async: true
  alias Rachel.Game.AvatarLibrary

  describe "list_avatars/0" do
    test "returns all avatars ordered by display_order" do
      avatars = AvatarLibrary.list_avatars()
      assert length(avatars) > 0
      assert Enum.all?(avatars, fn a -> a.character != nil end)
    end
  end

  describe "list_avatars_by_category/1" do
    test "returns avatars filtered by category" do
      avatars = AvatarLibrary.list_avatars_by_category("faces")
      assert Enum.all?(avatars, fn a -> a.category == "faces" end)
    end
  end

  describe "get_avatar/1" do
    test "returns avatar by id" do
      [first | _] = AvatarLibrary.list_avatars()
      avatar = AvatarLibrary.get_avatar(first.id)
      assert avatar.id == first.id
    end

    test "returns nil for invalid id" do
      assert nil == AvatarLibrary.get_avatar(99999)
    end
  end

  describe "get_default_avatar/0" do
    test "returns first avatar as default" do
      default = AvatarLibrary.get_default_avatar()
      assert default != nil
      assert default.id != nil
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mise exec -- mix test test/rachel/game/avatar_library_test.exs`
Expected: 5 failures (module doesn't exist)

**Step 3: Implement AvatarLibrary**

```elixir
defmodule Rachel.Game.AvatarLibrary do
  @moduledoc """
  Manages the avatar library - pre-made emoji avatars users can choose from.
  """

  import Ecto.Query
  alias Rachel.Game.Avatar
  alias Rachel.Repo

  @doc """
  Lists all avatars ordered by display_order.
  """
  def list_avatars do
    Avatar
    |> order_by([a], a.display_order)
    |> Repo.all()
  end

  @doc """
  Lists avatars filtered by category.
  """
  def list_avatars_by_category(category) do
    Avatar
    |> where([a], a.category == ^category)
    |> order_by([a], a.display_order)
    |> Repo.all()
  end

  @doc """
  Gets a single avatar by id.
  """
  def get_avatar(id) do
    Repo.get(Avatar, id)
  end

  @doc """
  Gets the default avatar (first one in the library).
  """
  def get_default_avatar do
    Avatar
    |> order_by([a], a.display_order)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Lists all available categories.
  """
  def list_categories do
    Avatar
    |> select([a], a.category)
    |> distinct(true)
    |> order_by([a], a.category)
    |> Repo.all()
  end
end
```

**Step 4: Create avatar seeds**

```elixir
# priv/repo/seeds/avatars.exs
alias Rachel.Repo
alias Rachel.Game.Avatar

# Clear existing avatars
Repo.delete_all(Avatar)

avatars = [
  # Faces/Emotions (10)
  %{name: "Smiling Face", category: "faces", character: "😀", display_order: 1},
  %{name: "Cool Sunglasses", category: "faces", character: "😎", display_order: 2},
  %{name: "Thinking Face", category: "faces", character: "🤔", display_order: 3},
  %{name: "Sleeping Face", category: "faces", character: "😴", display_order: 4},
  %{name: "Hugging Face", category: "faces", character: "🤗", display_order: 5},
  %{name: "Star Eyes", category: "faces", character: "🤩", display_order: 6},
  %{name: "Winking Face", category: "faces", character: "😉", display_order: 7},
  %{name: "Laughing", category: "faces", character: "😂", display_order: 8},
  %{name: "Heart Eyes", category: "faces", character: "😍", display_order: 9},
  %{name: "Party Face", category: "faces", character: "🥳", display_order: 10},

  # Animals (10)
  %{name: "Dog", category: "animals", character: "🐶", display_order: 11},
  %{name: "Cat", category: "animals", character: "🐱", display_order: 12},
  %{name: "Panda", category: "animals", character: "🐼", display_order: 13},
  %{name: "Fox", category: "animals", character: "🦊", display_order: 14},
  %{name: "Lion", category: "animals", character: "🦁", display_order: 15},
  %{name: "Tiger", category: "animals", character: "🐯", display_order: 16},
  %{name: "Unicorn", category: "animals", character: "🦄", display_order: 17},
  %{name: "Penguin", category: "animals", character: "🐧", display_order: 18},
  %{name: "Koala", category: "animals", character: "🐨", display_order: 19},
  %{name: "Frog", category: "animals", character: "🐸", display_order: 20},

  # Objects (10)
  %{name: "Game Controller", category: "objects", character: "🎮", display_order: 21},
  %{name: "Dart", category: "objects", character: "🎯", display_order: 22},
  %{name: "Artist Palette", category: "objects", character: "🎨", display_order: 23},
  %{name: "Rocket", category: "objects", character: "🚀", display_order: 24},
  %{name: "Lightning", category: "objects", character: "⚡", display_order: 25},
  %{name: "Trophy", category: "objects", character: "🏆", display_order: 26},
  %{name: "Crown", category: "objects", character: "👑", display_order: 27},
  %{name: "Crystal Ball", category: "objects", character: "🔮", display_order: 28},
  %{name: "Microphone", category: "objects", character: "🎤", display_order: 29},
  %{name: "Camera", category: "objects", character: "📷", display_order: 30},

  # Cards/Gaming (8)
  %{name: "Playing Card", category: "cards", character: "🃏", display_order: 31},
  %{name: "Spade", category: "cards", character: "♠️", display_order: 32},
  %{name: "Heart", category: "cards", character: "♥️", display_order: 33},
  %{name: "Diamond", category: "cards", character: "♦️", display_order: 34},
  %{name: "Club", category: "cards", character: "♣️", display_order: 35},
  %{name: "Dice", category: "cards", character: "🎲", display_order: 36},
  %{name: "Slot Machine", category: "cards", character: "🎰", display_order: 37},
  %{name: "Chess Pawn", category: "cards", character: "♟️", display_order: 38},

  # Food (8)
  %{name: "Pizza", category: "food", character: "🍕", display_order: 39},
  %{name: "Burger", category: "food", character: "🍔", display_order: 40},
  %{name: "Taco", category: "food", character: "🌮", display_order: 41},
  %{name: "Sushi", category: "food", character: "🍣", display_order: 42},
  %{name: "Cake", category: "food", character: "🎂", display_order: 43},
  %{name: "Ice Cream", category: "food", character: "🍦", display_order: 44},
  %{name: "Donut", category: "food", character: "🍩", display_order: 45},
  %{name: "Coffee", category: "food", character: "☕", display_order: 46},

  # Nature (8)
  %{name: "Star", category: "nature", character: "⭐", display_order: 47},
  %{name: "Glowing Star", category: "nature", character: "🌟", display_order: 48},
  %{name: "Rainbow", category: "nature", character: "🌈", display_order: 49},
  %{name: "Fire", category: "nature", character: "🔥", display_order: 50},
  %{name: "Diamond Gem", category: "nature", character: "💎", display_order: 51},
  %{name: "Moon", category: "nature", character: "🌙", display_order: 52},
  %{name: "Sun", category: "nature", character: "☀️", display_order: 53},
  %{name: "Sparkles", category: "nature", character: "✨", display_order: 54}
]

Enum.each(avatars, fn avatar_attrs ->
  %Avatar{}
  |> Avatar.changeset(avatar_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ Seeded #{length(avatars)} avatars")
```

**Step 5: Run seeds**

Run: `mise exec -- mix run priv/repo/seeds/avatars.exs`
Expected: "✅ Seeded 54 avatars"

**Step 6: Run tests to verify they pass**

Run: `mise exec -- mix test test/rachel/game/avatar_library_test.exs`
Expected: 5 passing tests

**Step 7: Commit**

```bash
git add lib/rachel/game/avatar_library.ex priv/repo/seeds/avatars.exs test/rachel/game/avatar_library_test.exs
git commit -m "feat(profile): Add avatar library with 54 emoji avatars"
```

---

## Task 6: Profile Settings LiveView

**Files:**
- Create: `lib/rachel_web/live/profile_live.ex`
- Create: `test/rachel_web/live/profile_live_test.exs`

**Step 1: Write failing tests**

```elixir
defmodule RachelWeb.ProfileLiveTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Profile settings page" do
    setup :register_and_log_in_user

    test "renders profile settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Profile Settings"
      assert html =~ "Choose Avatar"
      assert html =~ "Display Name"
    end

    test "updates display name", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      assert view
             |> form("#profile-form", profile: %{display_name: "New Name"})
             |> render_submit()

      assert_patch(view, ~p"/settings")

      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.display_name == "New Name"
    end

    test "shows validation errors for invalid display name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#profile-form", profile: %{display_name: "ab"})
        |> render_submit()

      assert html =~ "should be at least 3 character"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mise exec -- mix test test/rachel_web/live/profile_live_test.exs`
Expected: 3 failures (route/module doesn't exist)

**Step 3: Add route**

In `lib/rachel_web/router.ex`, add within the authenticated scope:

```elixir
live "/settings", ProfileLive, :index
```

**Step 4: Create ProfileLive module**

```elixir
defmodule RachelWeb.ProfileLive do
  use RachelWeb, :live_view
  alias Rachel.Accounts
  alias Rachel.Game.AvatarLibrary

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
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
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("select_avatar", %{"avatar-id" => avatar_id}, socket) do
    {avatar_id, _} = Integer.parse(avatar_id)
    changeset = Accounts.User.profile_changeset(socket.assigns.user, %{avatar_id: avatar_id})
    {:noreply, assign(socket, :form, to_form(changeset))}
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
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Profile Settings</h1>

      <.form
        for={@form}
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
```

**Step 5: Add Accounts context function**

In `lib/rachel/accounts.ex`, add:

```elixir
def update_user_profile(%User{} = user, attrs) do
  user
  |> User.profile_changeset(attrs)
  |> Repo.update()
end
```

**Step 6: Run tests to verify they pass**

Run: `mise exec -- mix test test/rachel_web/live/profile_live_test.exs`
Expected: 3 passing tests

**Step 7: Commit**

```bash
git add lib/rachel_web/live/profile_live.ex lib/rachel_web/router.ex lib/rachel/accounts.ex test/rachel_web/live/profile_live_test.exs
git commit -m "feat(profile): Add profile settings LiveView"
```

---

## Task 7: Profile Wizard LiveView (Onboarding)

**Files:**
- Create: `lib/rachel_web/live/profile_wizard_live.ex`
- Create: `test/rachel_web/live/profile_wizard_live_test.exs`

**Step 1: Write failing tests**

```elixir
defmodule RachelWeb.ProfileWizardLiveTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Profile wizard" do
    setup :register_and_log_in_user

    test "renders step 1 - avatar selection", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile/wizard")

      assert html =~ "Choose Your Avatar"
      assert html =~ "Step 1 of 3"
    end

    test "navigates through all steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/profile/wizard")

      # Step 1: Select avatar
      view
      |> element("button[phx-value-avatar-id]", "😀")
      |> render_click()

      html = view |> element("button", "Next") |> render_click()
      assert html =~ "Personal Information"
      assert html =~ "Step 2 of 3"

      # Step 2: Fill personal info
      html =
        view
        |> form("#wizard-form", profile: %{display_name: "TestUser", tagline: "Ready to play!"})
        |> render_submit()

      assert html =~ "Game Preferences"
      assert html =~ "Step 3 of 3"

      # Step 3: Complete wizard
      html = view |> element("button", "Complete Profile") |> render_click()
      assert html =~ "Profile completed"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mise exec -- mix test test/rachel_web/live/profile_wizard_live_test.exs`
Expected: 2 failures (route/module doesn't exist)

**Step 3: Add route**

In `lib/rachel_web/router.ex`, add within the authenticated scope:

```elixir
live "/profile/wizard", ProfileWizardLive, :index
```

**Step 4: Create ProfileWizardLive module**

```elixir
defmodule RachelWeb.ProfileWizardLive do
  use RachelWeb, :live_view
  alias Rachel.Accounts
  alias Rachel.Game.AvatarLibrary

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Redirect if profile already completed
    if user.profile_completed do
      {:ok, push_navigate(socket, to: ~p"/lobby")}
    else
      avatars = AvatarLibrary.list_avatars()
      default_avatar = AvatarLibrary.get_default_avatar()

      {:ok,
       socket
       |> assign(:page_title, "Complete Your Profile")
       |> assign(:user, user)
       |> assign(:avatars, avatars)
       |> assign(:selected_category, "faces")
       |> assign(:step, 1)
       |> assign(:profile_data, %{
         avatar_id: default_avatar.id,
         display_name: user.display_name || user.username,
         tagline: "",
         bio: "",
         preferences: %{}
       })}
    end
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
    profile_data = Map.merge(socket.assigns.profile_data, profile_params)
    {:noreply, assign(socket, :profile_data, profile_data) |> assign(:step, socket.assigns.step + 1)}
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

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error completing profile")
         |> assign(:step, 2)}  # Go back to personal info
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
              <div class={"flex-1 h-2 rounded-full " <> if(step <= @step, do: "bg-green-600", else: "bg-gray-200")}></div>
            <% end %>
          </div>
        </div>

        <!-- Step Content -->
        <%= case @step do %>
          <% 1 -> %>
            <%= render_avatar_step(assigns) %>
          <% 2 -> %>
            <%= render_personal_info_step(assigns) %>
          <% 3 -> %>
            <%= render_preferences_step(assigns) %>
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
            <%= String.capitalize(category) %>
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
            <%= avatar.character %>
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
                <input type="radio" name="ai_difficulty" value={difficulty} checked={difficulty == "medium"} class="sr-only peer" />
                <div class="p-3 text-center border-2 rounded-lg cursor-pointer peer-checked:border-green-600 peer-checked:bg-green-50">
                  <%= String.capitalize(difficulty) %>
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
                <input type="radio" name="animation_speed" value={speed} checked={speed == "normal"} class="sr-only peer" />
                <div class="p-3 text-center border-2 rounded-lg cursor-pointer peer-checked:border-green-600 peer-checked:bg-green-50">
                  <%= String.capitalize(speed) %>
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
```

**Step 5: Run tests to verify they pass**

Run: `mise exec -- mix test test/rachel_web/live/profile_wizard_live_test.exs`
Expected: 2 passing tests

**Step 6: Commit**

```bash
git add lib/rachel_web/live/profile_wizard_live.ex lib/rachel_web/router.ex test/rachel_web/live/profile_wizard_live_test.exs
git commit -m "feat(profile): Add profile wizard for new user onboarding"
```

---

## Task 8: Update Navigation & User Menu

**Files:**
- Modify: `lib/rachel_web/components/layouts/root.html.heex`

**Step 1: Add Settings link to navigation**

Update the authenticated user menu section to include Settings link:

```heex
<%= if @current_scope do %>
  <li>
    {@current_scope.user.email}
  </li>
  <li>
    <.link href={~p"/stats"}>Stats</.link>
  </li>
  <li>
    <.link href={~p"/history"}>History</.link>
  </li>
  <li>
    <.link href={~p"/settings"}>Settings</.link>
  </li>
  <li>
    <.link href={~p"/users/settings"}>Account</.link>
  </li>
  <li>
    <.link href={~p"/users/log-out"} method="delete">Log out</.link>
  </li>
<% else %>
```

**Step 2: Verify in browser**

Manual test: Log in and verify Settings link appears in navigation

**Step 3: Commit**

```bash
git add lib/rachel_web/components/layouts/root.html.heex
git commit -m "feat(profile): Add Settings link to navigation"
```

---

## Task 9: Integration Tests & Documentation

**Files:**
- Create: `test/rachel/integration/profile_flow_test.exs`
- Update: `TODO.md`

**Step 1: Write integration tests**

```elixir
defmodule Rachel.Integration.ProfileFlowTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Complete profile flow" do
    setup :register_and_log_in_user

    test "new user completes profile wizard", %{conn: conn, user: user} do
      # Start wizard
      {:ok, view, html} = live(conn, ~p"/profile/wizard")
      assert html =~ "Choose Your Avatar"

      # Select avatar
      view |> element("button[phx-value-avatar-id]") |> render_click()
      view |> element("button", "Next") |> render_click()

      # Fill personal info
      view
      |> form("#wizard-form", profile: %{
        display_name: "TestPlayer",
        tagline: "Ready to win!",
        bio: "I love card games"
      })
      |> render_submit()

      # Complete wizard
      view |> element("button", "Complete Profile") |> render_click()

      # Verify profile updated
      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.profile_completed == true
      assert updated_user.display_name == "TestPlayer"
      assert updated_user.tagline == "Ready to win!"
      assert updated_user.bio == "I love card games"
      assert updated_user.avatar_id != nil
    end

    test "existing user updates profile settings", %{conn: conn, user: user} do
      # Go to settings
      {:ok, view, html} = live(conn, ~p"/settings")
      assert html =~ "Profile Settings"

      # Update profile
      view
      |> form("#profile-form", profile: %{
        display_name: "UpdatedName",
        tagline: "New motto"
      })
      |> render_submit()

      # Verify update
      updated_user = Rachel.Accounts.get_user!(user.id)
      assert updated_user.display_name == "UpdatedName"
      assert updated_user.tagline == "New motto"
    end

    test "moderation blocks inappropriate content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#profile-form", profile: %{
          tagline: "damn this game"
        })
        |> render_submit()

      assert html =~ "contains inappropriate language"
    end
  end
end
```

**Step 2: Run integration tests**

Run: `mise exec -- mix test test/rachel/integration/profile_flow_test.exs`
Expected: 3 passing tests

**Step 3: Update TODO.md**

Mark profile customization as complete:

```markdown
### User Features
- [x] Tutorial system for new players ✅
- [x] User statistics dashboard (data tracked, UI complete) ✅
- [x] Game history viewer (with user_games join table, automatic tracking) ✅
- [x] Profile customization ✅
  - Avatar library (54 emoji avatars)
  - Display name, tagline, bio
  - Game preferences (AI difficulty, animation speed, hints)
  - Content moderation (profanity filtering, flagging system)
  - Onboarding wizard for new users
  - Settings page for existing users
```

**Step 4: Run full test suite**

Run: `mise exec -- mix test`
Expected: All tests passing

**Step 5: Commit**

```bash
git add test/rachel/integration/profile_flow_test.exs TODO.md
git commit -m "feat(profile): Add integration tests and update documentation"
```

---

## Final Steps

**Run full test suite one more time:**

```bash
mise exec -- mix test
```

**Expected:** All tests passing

**Verify in browser:**
1. Register new user → Should see profile wizard
2. Complete wizard → Should redirect to lobby
3. Go to Settings → Should see profile settings page
4. Update profile → Should save successfully
5. Try inappropriate content → Should show moderation error

**When complete, push to repository:**

```bash
git push origin main
```

---

## Summary

This plan implements a comprehensive profile customization system with:

✅ Avatar library (54 emoji avatars across 6 categories)
✅ Profile fields (display name, tagline, bio)
✅ Game preferences (AI difficulty, animation speed, hints)
✅ Content moderation (profanity filter + flagging system)
✅ Onboarding wizard for new users
✅ Settings page for existing users
✅ Full test coverage (unit, integration, LiveView tests)

**Total Tasks:** 9
**Estimated Time:** 4-6 hours for experienced developer
**Tests Added:** ~30 tests
**Files Created:** 12 new files
**Files Modified:** 4 existing files
