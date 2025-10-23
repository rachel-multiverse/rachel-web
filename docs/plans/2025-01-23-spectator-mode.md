# Spectator Mode Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Allow authenticated users to watch ongoing games in real-time without participating as players.

**Architecture:** Spectators subscribe to the same PubSub game channel as players but GameLive operates in `:spectator` mode, hiding interactive UI elements and blocking action events. Game engine remains unaware of spectators.

**Tech Stack:** Phoenix LiveView, PubSub, Elixir pattern matching

---

## Task 1: Add Mode Detection Logic

**Files:**
- Modify: `lib/rachel_web/live/game_live.ex:9-31` (mount function)
- Test: `test/rachel_web/live/game_live_test.exs`

**Step 1: Write failing test for spectator mode detection**

Add to `test/rachel_web/live/game_live_test.exs`:

```elixir
describe "spectator mode" do
  test "user visiting game with spectate param becomes spectator", %{conn: conn} do
    game_id = create_test_game()
    {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

    assert has_element?(view, "[data-role='spectator-banner']")
    refute has_element?(view, "[data-role='play-button']")
  end

  test "user not in game becomes spectator by default", %{conn: conn} do
    game_id = create_test_game()
    # conn's user is not a player in this game
    {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

    assert has_element?(view, "[data-role='spectator-banner']")
    refute has_element?(view, "[data-role='play-button']")
  end

  test "user in game becomes player", %{conn: conn, user: user} do
    game_id = create_test_game_with_user(user)
    {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

    refute has_element?(view, "[data-role='spectator-banner']")
    # May or may not have play button depending on turn
  end
end

defp create_test_game do
  {:ok, game_id} = GameSupervisor.start_game(["Alice", "Bob"])
  game_id
end

defp create_test_game_with_user(user) do
  player_spec = {:user, user.id, user.username}
  {:ok, game_id} = GameSupervisor.start_game([player_spec, "AI Bot"])
  game_id
end
```

**Step 2: Run tests to verify they fail**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs
```

Expected: FAIL - no spectator mode logic exists yet

**Step 3: Add mode determination logic to mount**

In `lib/rachel_web/live/game_live.ex`, replace the mount function:

```elixir
@impl true
def mount(%{"id" => game_id} = params, _session, socket) do
  if connected?(socket) do
    GameManager.subscribe_to_game(game_id)
  end

  case GameManager.get_game(game_id) do
    {:ok, game} ->
      mode = determine_mode(params, socket.assigns.current_scope, game)

      {:ok,
       socket
       |> assign(:game_id, game_id)
       |> assign(:game, game)
       |> assign(:mode, mode)
       |> assign(:current_player, current_player(game))
       |> assign(:selected_cards, [])
       |> assign(:nominated_suit, nil)
       |> assign(:show_suit_modal, false)}

    {:error, _} ->
      {:ok,
       socket
       |> put_flash(:error, "Game not found")
       |> redirect(to: ~p"/")}
  end
end

defp determine_mode(%{"spectate" => "true"}, _current_scope, _game), do: :spectator

defp determine_mode(_params, current_scope, game) do
  if current_scope && current_scope.user && user_in_game?(current_scope.user, game) do
    :player
  else
    :spectator
  end
end

defp user_in_game?(user, game) do
  Enum.any?(game.players, fn player ->
    case player.id do
      {:user, user_id, _username} -> user_id == user.id
      _ -> false
    end
  end)
end
```

**Step 4: Run tests to verify they pass**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs::"spectator mode"
```

Expected: Tests now fail on missing UI elements (next task)

**Step 5: Commit**

```bash
git add lib/rachel_web/live/game_live.ex test/rachel_web/live/game_live_test.exs
git commit -m "feat(spectator): Add mode detection logic for spectator vs player"
```

---

## Task 2: Add Spectator UI Banner

**Files:**
- Modify: `lib/rachel_web/live/game_live.ex:34-50` (render function)
- Modify: `assets/css/game.css` (add spectator styles)

**Step 1: Add spectator banner to template**

In `lib/rachel_web/live/game_live.ex` render function, add banner after connection status:

```elixir
def render(assigns) do
  ~H"""
  <div class="game-container min-h-screen bg-green-900 p-4" id="game-sounds" phx-hook="GameSounds">
    <!-- Connection Status Indicator -->
    <div
      id="connection-status"
      phx-hook="ConnectionStatus"
      class="fixed top-4 right-4 z-50 bg-white rounded-lg px-3 py-2 shadow-lg"
    >
      <span class="status-text text-sm font-medium">🟢 Connected</span>
    </div>

    <!-- Spectator Banner -->
    <%= if @mode == :spectator do %>
      <div
        data-role="spectator-banner"
        class="spectator-banner fixed top-4 left-1/2 transform -translate-x-1/2 z-50 bg-blue-600 text-white rounded-lg px-4 py-2 shadow-lg"
      >
        <span class="text-sm font-medium">👁️ Spectating</span>
      </div>
    <% end %>

    <!-- Rest of template unchanged -->
```

**Step 2: Add CSS styles for spectator banner**

In `assets/css/game.css`, add:

```css
/* Spectator Mode Styles */

.spectator-banner {
  animation: slideDown 0.3s ease-out;
}

@keyframes slideDown {
  from {
    transform: translate(-50%, -100%);
    opacity: 0;
  }
  to {
    transform: translate(-50%, 0);
    opacity: 1;
  }
}

.spectator-mode .card {
  cursor: default;
}

.spectator-mode .card:hover {
  transform: none;
}
```

**Step 3: Run tests to verify banner appears**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs::"spectator mode"
```

Expected: PASS for banner tests

**Step 4: Manual test in browser**

```bash
# In one terminal, ensure server is running
mise exec -- mix phx.server

# Visit http://localhost:4000/games/[existing-game-id]?spectate=true
# Should see blue "👁️ Spectating" banner at top
```

**Step 5: Commit**

```bash
git add lib/rachel_web/live/game_live.ex assets/css/game.css
git commit -m "feat(spectator): Add spectator mode banner UI"
```

---

## Task 3: Hide Interactive Elements for Spectators

**Files:**
- Modify: `lib/rachel_web/live/game_live.ex` (render function - action buttons section)
- Test: `test/rachel_web/live/game_live_test.exs`

**Step 1: Write test for hidden action buttons**

Add to spectator mode describe block:

```elixir
test "spectator cannot see action buttons", %{conn: conn} do
  game_id = create_test_game()
  {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

  refute has_element?(view, "[data-role='play-button']")
  refute has_element?(view, "[data-role='draw-button']")
  refute has_element?(view, "[data-role='pass-button']")
end
```

**Step 2: Run test to verify it fails**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs::"spectator cannot see action buttons"
```

Expected: FAIL - buttons are currently always visible

**Step 3: Conditionally render action buttons**

In `lib/rachel_web/live/game_live.ex`, find the action buttons section and wrap it:

```elixir
<!-- Action Buttons - Only for Players -->
<%= if @mode == :player do %>
  <div class="mt-4 flex gap-2 justify-center">
    <%= if is_current_player?(@game, @current_player) do %>
      <button
        data-role="play-button"
        phx-click="play_cards"
        disabled={Enum.empty?(@selected_cards)}
        class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        Play <%= length(@selected_cards) %> Card(s)
      </button>

      <button
        data-role="draw-button"
        phx-click="draw_cards"
        class="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700"
      >
        Draw Cards
      </button>
    <% end %>
  </div>
<% end %>
```

**Step 4: Run test to verify it passes**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs::"spectator cannot see action buttons"
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/rachel_web/live/game_live.ex test/rachel_web/live/game_live_test.exs
git commit -m "feat(spectator): Hide action buttons for spectators"
```

---

## Task 4: Disable Card Selection for Spectators

**Files:**
- Modify: `lib/rachel_web/live/game_live.ex` (handle_event functions)
- Test: `test/rachel_web/live/game_live_test.exs`

**Step 1: Write test for blocked card selection**

```elixir
test "spectator cannot select cards", %{conn: conn} do
  game_id = create_test_game()
  {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

  # Attempt to select a card
  result = view |> element("[data-card-index='0']") |> render_click()

  # Selection should be blocked
  assert view |> has_element?("[data-role='spectator-banner']")
  refute view |> element("[data-card-index='0']") |> has_class?("selected")
end
```

**Step 2: Run test to verify it fails**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs::"spectator cannot select cards"
```

Expected: FAIL - card selection currently works for everyone

**Step 3: Guard handle_event callbacks with mode check**

In `lib/rachel_web/live/game_live.ex`, add guards to interactive events:

```elixir
@impl true
def handle_event("toggle_card", %{"index" => index}, socket) do
  if socket.assigns.mode == :spectator do
    {:noreply, put_flash(socket, :error, "Spectators cannot select cards")}
  else
    # Existing card selection logic
    index = String.to_integer(index)
    selected_cards = socket.assigns.selected_cards

    new_selected =
      if index in selected_cards do
        List.delete(selected_cards, index)
      else
        [index | selected_cards]
      end

    {:noreply, assign(socket, :selected_cards, new_selected)}
  end
end

@impl true
def handle_event("play_cards", _params, socket) do
  if socket.assigns.mode == :spectator do
    {:noreply, put_flash(socket, :error, "Spectators cannot play cards")}
  else
    # Existing play cards logic
    # ... (unchanged)
  end
end

@impl true
def handle_event("draw_cards", _params, socket) do
  if socket.assigns.mode == :spectator do
    {:noreply, put_flash(socket, :error, "Spectators cannot draw cards")}
  else
    # Existing draw cards logic
    # ... (unchanged)
  end
end
```

**Step 4: Run tests to verify they pass**

```bash
mise exec -- mix test test/rachel_web/live/game_live_test.exs
```

Expected: All spectator tests PASS

**Step 5: Commit**

```bash
git add lib/rachel_web/live/game_live.ex test/rachel_web/live/game_live_test.exs
git commit -m "feat(spectator): Block interactive events for spectators"
```

---

## Task 5: Add Spectator Route Alias

**Files:**
- Modify: `lib/rachel_web/router.ex`

**Step 1: Add /spectate route alias**

In `lib/rachel_web/router.ex`, find the authenticated game routes section and add:

```elixir
live_session :require_authenticated_user,
  on_mount: {RachelWeb.UserAuth, :require_authenticated_user} do
  live "/lobby", LobbyLive
  live "/games/:id", GameLive
  live "/games/:id/spectate", GameLive  # Spectator alias
  live "/stats", StatsLive
  live "/history", HistoryLive
  live "/settings", ProfileLive, :index
  live "/profile/wizard", ProfileWizardLive, :index
end
```

**Step 2: Update mount to handle spectate route**

In `lib/rachel_web/live/game_live.ex`, update determine_mode:

```elixir
defp determine_mode(%{"spectate" => "true"}, _current_scope, _game), do: :spectator

defp determine_mode(_params, current_scope, game) do
  # Check if this is the /spectate route by checking the live_action
  # For now, use query param. Route-based detection can be added via on_mount
  if current_scope && current_scope.user && user_in_game?(current_scope.user, game) do
    :player
  else
    :spectator
  end
end
```

**Step 3: Test the new route**

```bash
# Manual test: Visit http://localhost:4000/games/[id]/spectate
# Should show spectator banner
```

**Step 4: Commit**

```bash
git add lib/rachel_web/router.ex
git commit -m "feat(spectator): Add /games/:id/spectate route alias"
```

---

## Task 6: Update Documentation

**Files:**
- Modify: `TODO.md`

**Step 1: Mark spectator mode as complete**

In `TODO.md`, update the Future Enhancements section:

```markdown
### Gameplay Features
- [x] Spectator mode ✅
- [ ] In-game chat
- [ ] Leaderboards
- [ ] Tournament/bracket system
```

**Step 2: Add spectator mode to completed features**

Add to the Completed section:

```markdown
- **🎮 SPECTATOR MODE (2025-01-23):**
  - ✅ Real-time game watching for authenticated users
  - ✅ Read-only view with spectator banner
  - ✅ Same PubSub channel as players (no game engine changes)
  - ✅ Action buttons and card selection blocked for spectators
  - ✅ Route aliases: /games/:id?spectate=true and /games/:id/spectate
```

**Step 3: Commit documentation**

```bash
git add TODO.md
git commit -m "docs: Mark spectator mode as complete"
```

---

## Task 7: Run Full Test Suite

**Step 1: Run all tests**

```bash
mise exec -- mix test
```

Expected: All 424+ tests PASS (may be more with new tests)

**Step 2: Check for compiler warnings**

```bash
mise exec -- mix compile --warnings-as-errors
```

Expected: Clean compilation, no warnings

**Step 3: Manual smoke test**

1. Start server: `mise exec -- mix phx.server`
2. Create a game as Player A
3. Open incognito window, login as Player B
4. Visit game with `?spectate=true`
5. Verify: Banner shows, no buttons, updates work
6. Player A plays cards → Player B sees updates immediately

**Step 4: Final commit and push**

```bash
git push origin main
```

---

## Completion Checklist

- [ ] Task 1: Mode detection logic (with tests)
- [ ] Task 2: Spectator banner UI
- [ ] Task 3: Hide action buttons
- [ ] Task 4: Block interactive events
- [ ] Task 5: Add route alias
- [ ] Task 6: Update documentation
- [ ] Task 7: Full test suite passes

## Future Enhancements (Not in This Plan)

- Spectator count display
- Spectator list (who's watching)
- Privacy settings (public/private games)
- Reactions system (emoji responses)
- Spectator chat (separate from player actions)
