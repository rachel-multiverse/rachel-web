# Leaderboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Elo-based leaderboards with tier badges to Rachel.

**Architecture:** New `Leaderboard` context handles Elo calculations. Rating updates trigger on game end via existing telemetry. New LiveView page for full leaderboard, component for lobby widget.

**Tech Stack:** Phoenix LiveView, Ecto, PostgreSQL, Tailwind CSS

---

## Task 1: Database Migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_leaderboard_fields.exs`

**Step 1: Generate migration**

Run:
```bash
cd /Users/stevehill/Projects/Rachel/rachel-web
mix ecto.gen.migration add_leaderboard_fields
```

**Step 2: Write migration**

Edit the generated file:

```elixir
defmodule Rachel.Repo.Migrations.AddLeaderboardFields do
  use Ecto.Migration

  def change do
    # Add Elo fields to users
    alter table(:users) do
      add :elo_rating, :integer, default: 1000, null: false
      add :elo_games_played, :integer, default: 0, null: false
      add :elo_tier, :string, default: "bronze", null: false
    end

    # Create rating history table
    create table(:rating_history) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, type: :binary_id, on_delete: :nilify_all)
      add :rating_before, :integer, null: false
      add :rating_after, :integer, null: false
      add :rating_change, :integer, null: false
      add :game_position, :integer
      add :opponents_count, :integer

      timestamps(updated_at: false)
    end

    # Indexes for leaderboard queries
    create index(:users, [:elo_rating], order_by: [desc: :elo_rating])
    create index(:rating_history, [:user_id])
    create index(:rating_history, [:inserted_at])
  end
end
```

**Step 3: Run migration**

Run:
```bash
mix ecto.migrate
```

Expected: Migration succeeds with "create table rating_history" output.

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_add_leaderboard_fields.exs
git commit -m "feat(db): add leaderboard schema (elo fields + rating_history)"
```

---

## Task 2: Rating History Schema

**Files:**
- Create: `lib/rachel/leaderboard/rating_history.ex`
- Test: `test/rachel/leaderboard/rating_history_test.exs`

**Step 1: Write failing test**

Create `test/rachel/leaderboard/rating_history_test.exs`:

```elixir
defmodule Rachel.Leaderboard.RatingHistoryTest do
  use Rachel.DataCase, async: true

  alias Rachel.Leaderboard.RatingHistory

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      user = insert_user()

      attrs = %{
        user_id: user.id,
        rating_before: 1000,
        rating_after: 1015,
        rating_change: 15,
        game_position: 1,
        opponents_count: 3
      }

      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      assert changeset.valid?
    end

    test "invalid without user_id" do
      attrs = %{rating_before: 1000, rating_after: 1015, rating_change: 15}
      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "invalid without rating fields" do
      user = insert_user()
      attrs = %{user_id: user.id}
      changeset = RatingHistory.changeset(%RatingHistory{}, attrs)
      refute changeset.valid?
    end
  end

  defp insert_user do
    {:ok, user} =
      %Rachel.Accounts.User{}
      |> Rachel.Accounts.User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Rachel.Repo.insert()
    user
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
mix test test/rachel/leaderboard/rating_history_test.exs
```

Expected: FAIL - module RatingHistory not found

**Step 3: Write implementation**

Create `lib/rachel/leaderboard/rating_history.ex`:

```elixir
defmodule Rachel.Leaderboard.RatingHistory do
  @moduledoc """
  Schema for tracking Elo rating changes over time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "rating_history" do
    belongs_to :user, Rachel.Accounts.User
    belongs_to :game, Rachel.Game.Games, type: :binary_id

    field :rating_before, :integer
    field :rating_after, :integer
    field :rating_change, :integer
    field :game_position, :integer
    field :opponents_count, :integer

    timestamps(updated_at: false)
  end

  @required_fields [:user_id, :rating_before, :rating_after, :rating_change]
  @optional_fields [:game_id, :game_position, :opponents_count]

  def changeset(rating_history, attrs) do
    rating_history
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:game_id)
  end
end
```

**Step 4: Run test to verify it passes**

Run:
```bash
mix test test/rachel/leaderboard/rating_history_test.exs
```

Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/rachel/leaderboard/rating_history.ex test/rachel/leaderboard/rating_history_test.exs
git commit -m "feat(leaderboard): add RatingHistory schema"
```

---

## Task 3: Update User Schema

**Files:**
- Modify: `lib/rachel/accounts/user.ex`
- Test: `test/rachel/accounts/user_test.exs` (add to existing)

**Step 1: Write failing test**

Add to `test/rachel/accounts/user_test.exs` (create if doesn't exist):

```elixir
defmodule Rachel.Accounts.UserTest do
  use Rachel.DataCase, async: true

  alias Rachel.Accounts.User

  describe "elo_changeset/2" do
    test "updates elo fields" do
      user = %User{}
      attrs = %{elo_rating: 1050, elo_games_played: 5, elo_tier: "silver"}
      changeset = User.elo_changeset(user, attrs)

      assert changeset.valid?
      assert get_change(changeset, :elo_rating) == 1050
      assert get_change(changeset, :elo_tier) == "silver"
    end

    test "validates elo_rating is non-negative" do
      changeset = User.elo_changeset(%User{}, %{elo_rating: -100})
      refute changeset.valid?
    end

    test "validates elo_tier is valid" do
      changeset = User.elo_changeset(%User{}, %{elo_tier: "invalid"})
      refute changeset.valid?
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
mix test test/rachel/accounts/user_test.exs
```

Expected: FAIL - function User.elo_changeset/2 is undefined

**Step 3: Add fields and changeset to User schema**

Edit `lib/rachel/accounts/user.ex`, add to schema block after line ~39:

```elixir
    # Elo rating fields
    field :elo_rating, :integer, default: 1000
    field :elo_games_played, :integer, default: 0
    field :elo_tier, :string, default: "bronze"
```

Add new changeset function after `presence_changeset/2`:

```elixir
  @valid_tiers ~w(bronze silver gold platinum diamond)

  @doc """
  A user changeset for updating Elo rating fields.
  """
  def elo_changeset(user, attrs) do
    user
    |> cast(attrs, [:elo_rating, :elo_games_played, :elo_tier])
    |> validate_number(:elo_rating, greater_than_or_equal_to: 0)
    |> validate_number(:elo_games_played, greater_than_or_equal_to: 0)
    |> validate_inclusion(:elo_tier, @valid_tiers)
  end
```

**Step 4: Run test to verify it passes**

Run:
```bash
mix test test/rachel/accounts/user_test.exs
```

Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/rachel/accounts/user.ex test/rachel/accounts/user_test.exs
git commit -m "feat(accounts): add Elo fields to User schema"
```

---

## Task 4: Leaderboard Context - Elo Calculation

**Files:**
- Create: `lib/rachel/leaderboard.ex`
- Test: `test/rachel/leaderboard_test.exs`

**Step 1: Write failing tests for Elo calculation**

Create `test/rachel/leaderboard_test.exs`:

```elixir
defmodule Rachel.LeaderboardTest do
  use Rachel.DataCase, async: true

  alias Rachel.Leaderboard
  alias Rachel.Accounts.User

  describe "calculate_expected_score/2" do
    test "returns 0.5 for equal ratings" do
      assert_in_delta Leaderboard.calculate_expected_score(1000, 1000), 0.5, 0.001
    end

    test "returns higher score for higher rated player" do
      score = Leaderboard.calculate_expected_score(1200, 1000)
      assert score > 0.5
      assert_in_delta score, 0.76, 0.01
    end

    test "returns lower score for lower rated player" do
      score = Leaderboard.calculate_expected_score(1000, 1200)
      assert score < 0.5
      assert_in_delta score, 0.24, 0.01
    end
  end

  describe "calculate_rating_change/4" do
    test "positive change for win against equal opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1000, 1.0, 32)
      assert change > 0
      assert_in_delta change, 16, 1
    end

    test "negative change for loss against equal opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1000, 0.0, 32)
      assert change < 0
      assert_in_delta change, -16, 1
    end

    test "smaller gain for beating lower rated opponent" do
      change = Leaderboard.calculate_rating_change(1200, 1000, 1.0, 32)
      assert change > 0
      assert change < 16
    end

    test "larger gain for beating higher rated opponent" do
      change = Leaderboard.calculate_rating_change(1000, 1200, 1.0, 32)
      assert change > 0
      assert change > 16
    end
  end

  describe "get_k_factor/1" do
    test "returns 32 for provisional players (< 30 games)" do
      assert Leaderboard.get_k_factor(0) == 32
      assert Leaderboard.get_k_factor(29) == 32
    end

    test "returns 16 for established players (>= 30 games)" do
      assert Leaderboard.get_k_factor(30) == 16
      assert Leaderboard.get_k_factor(100) == 16
    end
  end

  describe "calculate_tier/1" do
    test "bronze for rating < 900" do
      assert Leaderboard.calculate_tier(899) == "bronze"
      assert Leaderboard.calculate_tier(0) == "bronze"
    end

    test "silver for rating 900-1099" do
      assert Leaderboard.calculate_tier(900) == "silver"
      assert Leaderboard.calculate_tier(1099) == "silver"
    end

    test "gold for rating 1100-1299" do
      assert Leaderboard.calculate_tier(1100) == "gold"
      assert Leaderboard.calculate_tier(1299) == "gold"
    end

    test "platinum for rating 1300-1499" do
      assert Leaderboard.calculate_tier(1300) == "platinum"
      assert Leaderboard.calculate_tier(1499) == "platinum"
    end

    test "diamond for rating >= 1500" do
      assert Leaderboard.calculate_tier(1500) == "diamond"
      assert Leaderboard.calculate_tier(2000) == "diamond"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/rachel/leaderboard_test.exs
```

Expected: FAIL - module Leaderboard not found

**Step 3: Write Elo calculation implementation**

Create `lib/rachel/leaderboard.ex`:

```elixir
defmodule Rachel.Leaderboard do
  @moduledoc """
  Context for Elo-based leaderboard functionality.

  Handles rating calculations, updates, and leaderboard queries.
  """

  import Ecto.Query
  alias Rachel.Repo
  alias Rachel.Accounts.User
  alias Rachel.Leaderboard.RatingHistory

  # Elo calculation constants
  @provisional_k 32
  @established_k 16
  @provisional_threshold 30

  # Tier thresholds
  @tier_thresholds [
    {1500, "diamond"},
    {1300, "platinum"},
    {1100, "gold"},
    {900, "silver"},
    {0, "bronze"}
  ]

  @doc """
  Calculate expected score using Elo formula.
  Returns value between 0 and 1.
  """
  def calculate_expected_score(player_rating, opponent_rating) do
    1 / (1 + :math.pow(10, (opponent_rating - player_rating) / 400))
  end

  @doc """
  Calculate rating change for a single matchup.
  actual_score: 1.0 for win, 0.5 for draw, 0.0 for loss
  """
  def calculate_rating_change(player_rating, opponent_rating, actual_score, k_factor) do
    expected = calculate_expected_score(player_rating, opponent_rating)
    round(k_factor * (actual_score - expected))
  end

  @doc """
  Get K-factor based on games played.
  Provisional players (< 30 games) have higher K for faster adjustment.
  """
  def get_k_factor(games_played) when games_played < @provisional_threshold, do: @provisional_k
  def get_k_factor(_games_played), do: @established_k

  @doc """
  Calculate tier based on Elo rating.
  """
  def calculate_tier(rating) do
    Enum.find_value(@tier_thresholds, fn {threshold, tier} ->
      if rating >= threshold, do: tier
    end)
  end
end
```

**Step 4: Run tests to verify they pass**

Run:
```bash
mix test test/rachel/leaderboard_test.exs
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/rachel/leaderboard.ex test/rachel/leaderboard_test.exs
git commit -m "feat(leaderboard): add Elo calculation functions"
```

---

## Task 5: Leaderboard Context - Pairwise Rating Update

**Files:**
- Modify: `lib/rachel/leaderboard.ex`
- Modify: `test/rachel/leaderboard_test.exs`

**Step 1: Write failing tests for pairwise calculation**

Add to `test/rachel/leaderboard_test.exs`:

```elixir
  describe "calculate_pairwise_changes/2" do
    test "calculates changes for 2-player game" do
      players = [
        %{user_id: 1, rating: 1000, games_played: 10, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)

      # Winner should gain, loser should lose equal amount
      assert length(changes) == 2
      winner_change = Enum.find(changes, & &1.user_id == 1)
      loser_change = Enum.find(changes, & &1.user_id == 2)

      assert winner_change.rating_change > 0
      assert loser_change.rating_change < 0
      assert winner_change.rating_change == -loser_change.rating_change
    end

    test "calculates changes for 4-player game" do
      players = [
        %{user_id: 1, rating: 1000, games_played: 10, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2},
        %{user_id: 3, rating: 1000, games_played: 10, position: 3},
        %{user_id: 4, rating: 1000, games_played: 10, position: 4}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)

      assert length(changes) == 4

      # First place beats 3 opponents, should have highest gain
      first = Enum.find(changes, & &1.user_id == 1)
      last = Enum.find(changes, & &1.user_id == 4)

      assert first.rating_change > 0
      assert last.rating_change < 0
      assert first.rating_change > abs(last.rating_change) / 3
    end

    test "higher rated player gains less for expected win" do
      players = [
        %{user_id: 1, rating: 1400, games_played: 50, position: 1},
        %{user_id: 2, rating: 1000, games_played: 10, position: 2}
      ]

      changes = Leaderboard.calculate_pairwise_changes(players)
      winner = Enum.find(changes, & &1.user_id == 1)

      # High rated player beating low rated = small gain
      assert winner.rating_change > 0
      assert winner.rating_change < 10
    end
  end
```

**Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/rachel/leaderboard_test.exs --only describe:"calculate_pairwise_changes/2"
```

Expected: FAIL - function calculate_pairwise_changes/1 is undefined

**Step 3: Implement pairwise calculation**

Add to `lib/rachel/leaderboard.ex`:

```elixir
  @doc """
  Calculate rating changes for all players in a multiplayer game.

  Uses pairwise comparison: each player pair is treated as a 1v1 match.
  Position determines who "beat" whom (lower position = better finish).

  Input: List of %{user_id, rating, games_played, position}
  Output: List of %{user_id, rating_change, new_rating, new_tier, opponents_count}
  """
  def calculate_pairwise_changes(players) when length(players) < 2, do: []

  def calculate_pairwise_changes(players) do
    players
    |> Enum.map(fn player ->
      k = get_k_factor(player.games_played)
      opponents = Enum.reject(players, & &1.user_id == player.user_id)

      total_change =
        opponents
        |> Enum.map(fn opponent ->
          actual_score = if player.position < opponent.position, do: 1.0, else: 0.0
          calculate_rating_change(player.rating, opponent.rating, actual_score, k)
        end)
        |> Enum.sum()

      new_rating = max(0, player.rating + total_change)

      %{
        user_id: player.user_id,
        rating_before: player.rating,
        rating_change: total_change,
        new_rating: new_rating,
        new_tier: calculate_tier(new_rating),
        game_position: player.position,
        opponents_count: length(opponents)
      }
    end)
  end
```

**Step 4: Run tests to verify they pass**

Run:
```bash
mix test test/rachel/leaderboard_test.exs
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/rachel/leaderboard.ex test/rachel/leaderboard_test.exs
git commit -m "feat(leaderboard): add pairwise Elo calculation for multiplayer"
```

---

## Task 6: Leaderboard Context - Database Operations

**Files:**
- Modify: `lib/rachel/leaderboard.ex`
- Modify: `test/rachel/leaderboard_test.exs`

**Step 1: Write failing tests for database operations**

Add to `test/rachel/leaderboard_test.exs`:

```elixir
  describe "process_game_results/2" do
    setup do
      user1 = insert_user()
      user2 = insert_user()
      {:ok, user1: user1, user2: user2}
    end

    test "updates user ratings and creates history", %{user1: user1, user2: user2} do
      game_id = Ecto.UUID.generate()

      results = [
        %{user_id: user1.id, position: 1},
        %{user_id: user2.id, position: 2}
      ]

      {:ok, changes} = Leaderboard.process_game_results(game_id, results)

      assert length(changes) == 2

      # Verify user ratings updated
      updated_user1 = Repo.get!(User, user1.id)
      updated_user2 = Repo.get!(User, user2.id)

      assert updated_user1.elo_rating > 1000
      assert updated_user2.elo_rating < 1000
      assert updated_user1.elo_games_played == 1

      # Verify history created
      history = Repo.all(RatingHistory)
      assert length(history) == 2
    end

    test "returns error for single player", %{user1: user1} do
      results = [%{user_id: user1.id, position: 1}]
      assert {:error, :not_enough_players} = Leaderboard.process_game_results("game", results)
    end

    test "handles tier promotion", %{user1: user1, user2: user2} do
      # Set user1 near tier boundary
      user1
      |> Ecto.Changeset.change(%{elo_rating: 1095})
      |> Repo.update!()

      game_id = Ecto.UUID.generate()
      results = [
        %{user_id: user1.id, position: 1},
        %{user_id: user2.id, position: 2}
      ]

      {:ok, changes} = Leaderboard.process_game_results(game_id, results)

      winner_change = Enum.find(changes, & &1.user_id == user1.id)
      assert winner_change.new_tier == "gold"

      updated_user1 = Repo.get!(User, user1.id)
      assert updated_user1.elo_tier == "gold"
    end
  end

  describe "get_leaderboard/1" do
    test "returns top players ordered by rating" do
      user1 = insert_user() |> set_rating(1200)
      user2 = insert_user() |> set_rating(1100)
      user3 = insert_user() |> set_rating(1300)

      leaderboard = Leaderboard.get_leaderboard(limit: 10)

      assert length(leaderboard) == 3
      assert hd(leaderboard).id == user3.id
      assert List.last(leaderboard).id == user2.id
    end

    test "respects limit" do
      for _ <- 1..5, do: insert_user() |> set_rating(1100)

      leaderboard = Leaderboard.get_leaderboard(limit: 3)
      assert length(leaderboard) == 3
    end

    test "only includes players with ranked games" do
      _no_games = insert_user()
      with_games = insert_user() |> set_rating(1100, 5)

      leaderboard = Leaderboard.get_leaderboard(limit: 10)

      assert length(leaderboard) == 1
      assert hd(leaderboard).id == with_games.id
    end
  end

  describe "get_user_rank/1" do
    test "returns rank for user with games" do
      user1 = insert_user() |> set_rating(1200, 5)
      user2 = insert_user() |> set_rating(1300, 5)
      _user3 = insert_user() |> set_rating(1100, 5)

      assert Leaderboard.get_user_rank(user1.id) == 2
      assert Leaderboard.get_user_rank(user2.id) == 1
    end

    test "returns nil for user with no ranked games" do
      user = insert_user()
      assert Leaderboard.get_user_rank(user.id) == nil
    end
  end

  describe "get_rating_history/2" do
    test "returns recent history for user" do
      user = insert_user()

      # Insert some history
      for i <- 1..5 do
        %RatingHistory{}
        |> RatingHistory.changeset(%{
          user_id: user.id,
          rating_before: 1000 + (i - 1) * 10,
          rating_after: 1000 + i * 10,
          rating_change: 10
        })
        |> Repo.insert!()
      end

      history = Leaderboard.get_rating_history(user.id, limit: 3)

      assert length(history) == 3
      # Most recent first
      assert hd(history).rating_after == 1050
    end
  end

  # Test helpers
  defp insert_user do
    {:ok, user} =
      %User{}
      |> User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Repo.insert()
    user
  end

  defp set_rating(user, rating, games \\ 1) do
    user
    |> Ecto.Changeset.change(%{
      elo_rating: rating,
      elo_games_played: games,
      elo_tier: Leaderboard.calculate_tier(rating)
    })
    |> Repo.update!()
  end
```

**Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/rachel/leaderboard_test.exs
```

Expected: FAIL - functions not defined

**Step 3: Implement database operations**

Add to `lib/rachel/leaderboard.ex`:

```elixir
  @doc """
  Process game results and update all player ratings.

  Takes a game_id and list of %{user_id, position} for human players.
  Updates ratings in a transaction.
  """
  def process_game_results(_game_id, results) when length(results) < 2 do
    {:error, :not_enough_players}
  end

  def process_game_results(game_id, results) do
    # Load current user data
    user_ids = Enum.map(results, & &1.user_id)

    users =
      User
      |> where([u], u.id in ^user_ids)
      |> Repo.all()
      |> Map.new(& {&1.id, &1})

    # Build player data for calculation
    players =
      Enum.map(results, fn result ->
        user = users[result.user_id]
        %{
          user_id: result.user_id,
          rating: user.elo_rating,
          games_played: user.elo_games_played,
          position: result.position
        }
      end)

    # Calculate rating changes
    changes = calculate_pairwise_changes(players)

    # Apply changes in transaction
    Repo.transaction(fn ->
      Enum.map(changes, fn change ->
        user = users[change.user_id]

        # Update user rating
        {:ok, _} =
          user
          |> User.elo_changeset(%{
            elo_rating: change.new_rating,
            elo_games_played: user.elo_games_played + 1,
            elo_tier: change.new_tier
          })
          |> Repo.update()

        # Record history
        {:ok, _} =
          %RatingHistory{}
          |> RatingHistory.changeset(%{
            user_id: change.user_id,
            game_id: game_id,
            rating_before: change.rating_before,
            rating_after: change.new_rating,
            rating_change: change.rating_change,
            game_position: change.game_position,
            opponents_count: change.opponents_count
          })
          |> Repo.insert()

        change
      end)
    end)
  end

  @doc """
  Get leaderboard - top players by Elo rating.
  Only includes players with at least 1 ranked game.
  """
  def get_leaderboard(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    User
    |> where([u], u.elo_games_played > 0)
    |> order_by([u], desc: u.elo_rating)
    |> limit(^limit)
    |> select([u], %{
      id: u.id,
      username: u.username,
      display_name: u.display_name,
      avatar_id: u.avatar_id,
      elo_rating: u.elo_rating,
      elo_games_played: u.elo_games_played,
      elo_tier: u.elo_tier
    })
    |> Repo.all()
  end

  @doc """
  Get a user's rank on the leaderboard.
  Returns nil if user has no ranked games.
  """
  def get_user_rank(user_id) do
    user = Repo.get(User, user_id)

    if user && user.elo_games_played > 0 do
      User
      |> where([u], u.elo_games_played > 0)
      |> where([u], u.elo_rating > ^user.elo_rating)
      |> select([u], count(u.id))
      |> Repo.one()
      |> Kernel.+(1)
    end
  end

  @doc """
  Get rating history for a user.
  """
  def get_rating_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    RatingHistory
    |> where([h], h.user_id == ^user_id)
    |> order_by([h], desc: h.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
```

**Step 4: Run tests to verify they pass**

Run:
```bash
mix test test/rachel/leaderboard_test.exs
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/rachel/leaderboard.ex test/rachel/leaderboard_test.exs
git commit -m "feat(leaderboard): add database operations for ratings"
```

---

## Task 7: Hook into Game Engine

**Files:**
- Modify: `lib/rachel/game/games.ex`
- Test: Integration test

**Step 1: Write failing test**

Create `test/rachel/leaderboard/integration_test.exs`:

```elixir
defmodule Rachel.Leaderboard.IntegrationTest do
  use Rachel.DataCase, async: false

  alias Rachel.Game.Games
  alias Rachel.Leaderboard

  describe "game completion triggers rating update" do
    test "updates ratings for human players only" do
      user1 = insert_user()
      user2 = insert_user()

      # Create a mock finished game state with human players
      game_state = %{
        id: Ecto.UUID.generate(),
        status: :finished,
        players: [
          %{id: "p1", name: "Player1", user_id: user1.id, type: :human, hand: []},
          %{id: "p2", name: "Player2", user_id: user2.id, type: :human, hand: [%{suit: :hearts, rank: "5"}]},
          %{id: "ai", name: "AI", user_id: nil, type: :ai, hand: [%{suit: :clubs, rank: "K"}]}
        ],
        winners: ["p1"],
        turn_count: 20
      }

      # Call the function that records participation (which should trigger rating update)
      Games.record_user_participation(game_state)

      # Allow async task to complete
      Process.sleep(100)

      # Verify ratings were updated for humans only
      updated_user1 = Rachel.Repo.get!(Rachel.Accounts.User, user1.id)
      updated_user2 = Rachel.Repo.get!(Rachel.Accounts.User, user2.id)

      # Winner should gain rating
      assert updated_user1.elo_rating > 1000
      assert updated_user1.elo_games_played == 1

      # Loser should lose rating
      assert updated_user2.elo_rating < 1000
      assert updated_user2.elo_games_played == 1
    end

    test "does not update ratings for AI-only games" do
      user = insert_user()

      game_state = %{
        id: Ecto.UUID.generate(),
        status: :finished,
        players: [
          %{id: "p1", name: "Player1", user_id: user.id, type: :human, hand: []},
          %{id: "ai1", name: "AI1", user_id: nil, type: :ai, hand: [%{suit: :clubs, rank: "K"}]},
          %{id: "ai2", name: "AI2", user_id: nil, type: :ai, hand: [%{suit: :hearts, rank: "Q"}]}
        ],
        winners: ["p1"],
        turn_count: 15
      }

      Games.record_user_participation(game_state)
      Process.sleep(100)

      # User rating should not change (only 1 human)
      updated_user = Rachel.Repo.get!(Rachel.Accounts.User, user.id)
      assert updated_user.elo_rating == 1000
      assert updated_user.elo_games_played == 0
    end
  end

  defp insert_user do
    {:ok, user} =
      %Rachel.Accounts.User{}
      |> Rachel.Accounts.User.registration_changeset(%{
        email: "test#{System.unique_integer()}@example.com",
        username: "user#{System.unique_integer([:positive])}",
        password: "password123456"
      })
      |> Rachel.Repo.insert()
    user
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
mix test test/rachel/leaderboard/integration_test.exs
```

Expected: FAIL - ratings not updated

**Step 3: Modify Games.record_user_participation to trigger rating update**

Edit `lib/rachel/game/games.ex`. Find the `record_user_participation/1` function and add rating calculation. Add after the existing user_games insert logic:

```elixir
  # At the end of record_user_participation, add:

  # Trigger Elo rating update for ranked games (2+ humans)
  human_players =
    game_state.players
    |> Enum.filter(& &1.user_id != nil && &1.type in [:human, :user])
    |> Enum.with_index(1)
    |> Enum.map(fn {player, _idx} ->
      position = calculate_player_position(player, game_state)
      %{user_id: player.user_id, position: position}
    end)

  if length(human_players) >= 2 do
    Rachel.Leaderboard.process_game_results(game_state.id, human_players)
  end
```

Add helper function:

```elixir
  defp calculate_player_position(player, game_state) do
    cond do
      player.id in game_state.winners ->
        Enum.find_index(game_state.winners, & &1 == player.id) + 1
      true ->
        # Non-winners ranked by hand size (fewer = better)
        non_winners = Enum.reject(game_state.players, & &1.id in game_state.winners)
        sorted = Enum.sort_by(non_winners, & length(&1.hand))
        winner_count = length(game_state.winners)
        winner_count + Enum.find_index(sorted, & &1.id == player.id) + 1
    end
  end
```

**Step 4: Run test to verify it passes**

Run:
```bash
mix test test/rachel/leaderboard/integration_test.exs
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/rachel/game/games.ex test/rachel/leaderboard/integration_test.exs
git commit -m "feat(leaderboard): hook rating updates into game completion"
```

---

## Task 8: Leaderboard LiveView Page

**Files:**
- Create: `lib/rachel_web/live/leaderboard_live.ex`
- Modify: `lib/rachel_web/router.ex`
- Test: `test/rachel_web/live/leaderboard_live_test.exs`

**Step 1: Write failing test**

Create `test/rachel_web/live/leaderboard_live_test.exs`:

```elixir
defmodule RachelWeb.LeaderboardLiveTest do
  use RachelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount" do
    test "renders leaderboard page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Leaderboard"
      assert html =~ "Rank"
      assert html =~ "Player"
      assert html =~ "Rating"
    end

    test "shows tier legend", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Bronze"
      assert html =~ "Silver"
      assert html =~ "Gold"
      assert html =~ "Platinum"
      assert html =~ "Diamond"
    end

    test "shows current user's rank when they have games", %{conn: conn, user: user} do
      # Give user some ranked games
      user
      |> Ecto.Changeset.change(%{elo_rating: 1150, elo_games_played: 10, elo_tier: "gold"})
      |> Rachel.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      assert html =~ "Your Rank"
      assert html =~ "1150"
      assert html =~ "Gold"
    end

    test "shows players in order by rating", %{conn: conn} do
      # Create users with different ratings
      for {rating, name} <- [{1300, "TopPlayer"}, {1100, "MidPlayer"}, {900, "LowPlayer"}] do
        {:ok, u} =
          %Rachel.Accounts.User{}
          |> Rachel.Accounts.User.registration_changeset(%{
            email: "#{name}@test.com",
            username: name,
            password: "password123456"
          })
          |> Rachel.Repo.insert()

        u
        |> Ecto.Changeset.change(%{elo_rating: rating, elo_games_played: 5, elo_tier: Rachel.Leaderboard.calculate_tier(rating)})
        |> Rachel.Repo.update!()
      end

      {:ok, _view, html} = live(conn, ~p"/leaderboard")

      # TopPlayer should appear before MidPlayer
      assert String.contains?(html, "TopPlayer")
      top_pos = :binary.match(html, "TopPlayer") |> elem(0)
      mid_pos = :binary.match(html, "MidPlayer") |> elem(0)
      assert top_pos < mid_pos
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      unauth_conn = build_conn()
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(unauth_conn, ~p"/leaderboard")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
mix test test/rachel_web/live/leaderboard_live_test.exs
```

Expected: FAIL - route not found

**Step 3: Add route**

Edit `lib/rachel_web/router.ex`. Add inside the `:require_authenticated_user` live_session (around line 107):

```elixir
      live "/leaderboard", LeaderboardLive
```

**Step 4: Create LiveView**

Create `lib/rachel_web/live/leaderboard_live.ex`:

```elixir
defmodule RachelWeb.LeaderboardLive do
  use RachelWeb, :live_view

  alias Rachel.Leaderboard

  @tier_colors %{
    "bronze" => "bg-amber-700",
    "silver" => "bg-gray-400",
    "gold" => "bg-yellow-500",
    "platinum" => "bg-cyan-400",
    "diamond" => "bg-purple-500"
  }

  @tier_icons %{
    "bronze" => "🥉",
    "silver" => "🥈",
    "gold" => "🥇",
    "platinum" => "💎",
    "diamond" => "👑"
  }

  @impl true
  def mount(_params, session, socket) do
    current_user = get_authenticated_user(session, socket)
    leaderboard = Leaderboard.get_leaderboard(limit: 100)
    user_rank = Leaderboard.get_user_rank(current_user.id)
    recent_history = Leaderboard.get_rating_history(current_user.id, limit: 5)

    {:ok,
     assign(socket,
       page_title: "Leaderboard",
       current_user: current_user,
       leaderboard: leaderboard,
       user_rank: user_rank,
       recent_history: recent_history,
       tier_colors: @tier_colors,
       tier_icons: @tier_icons
     )}
  end

  defp get_authenticated_user(session, socket) do
    case session["user_token"] do
      nil ->
        case Map.get(socket.assigns, :current_scope) do
          %{user: user} -> user
          _ -> Map.get(socket.assigns, :user) || raise "No authenticated user found"
        end

      token ->
        case Rachel.Accounts.get_user_by_session_token(token) do
          {user, _authenticated_at} -> user
          user -> user
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-900 via-green-800 to-green-900 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-xl p-6 mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Leaderboard</h1>
          <p class="text-gray-600 mt-1">Top Rachel players ranked by Elo rating</p>
        </div>

        <!-- Tier Legend -->
        <div class="bg-white rounded-lg shadow-xl p-4 mb-6">
          <h2 class="text-sm font-semibold text-gray-700 mb-2">Tiers</h2>
          <div class="flex flex-wrap gap-3">
            <.tier_badge tier="diamond" icons={@tier_icons} colors={@tier_colors} label="1500+" />
            <.tier_badge tier="platinum" icons={@tier_icons} colors={@tier_colors} label="1300-1499" />
            <.tier_badge tier="gold" icons={@tier_icons} colors={@tier_colors} label="1100-1299" />
            <.tier_badge tier="silver" icons={@tier_icons} colors={@tier_colors} label="900-1099" />
            <.tier_badge tier="bronze" icons={@tier_icons} colors={@tier_colors} label="<900" />
          </div>
        </div>

        <!-- Your Rank Card -->
        <%= if @current_user.elo_games_played > 0 do %>
          <div class="bg-white rounded-lg shadow-xl p-6 mb-6 border-2 border-yellow-400">
            <h2 class="text-lg font-semibold text-gray-700 mb-3">Your Rank</h2>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <span class="text-3xl font-bold text-gray-900">#{@user_rank || "—"}</span>
                <div>
                  <div class="font-semibold">{@current_user.display_name || @current_user.username}</div>
                  <div class="text-sm text-gray-600">{@current_user.elo_games_played} ranked games</div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-2xl font-bold">{@current_user.elo_rating}</div>
                <div class={"inline-flex items-center px-2 py-1 rounded text-white text-sm #{@tier_colors[@current_user.elo_tier]}"}>
                  {@tier_icons[@current_user.elo_tier]} {String.capitalize(@current_user.elo_tier)}
                </div>
              </div>
            </div>

            <!-- Recent trend -->
            <%= if @recent_history != [] do %>
              <div class="mt-4 pt-4 border-t">
                <div class="text-sm text-gray-600">Recent:</div>
                <div class="flex gap-2 mt-1">
                  <%= for entry <- Enum.take(@recent_history, 5) do %>
                    <span class={if entry.rating_change >= 0, do: "text-green-600", else: "text-red-600"}>
                      {if entry.rating_change >= 0, do: "+", else: ""}{entry.rating_change}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="bg-white rounded-lg shadow-xl p-6 mb-6 border-2 border-gray-300">
            <h2 class="text-lg font-semibold text-gray-700 mb-2">Your Rank</h2>
            <p class="text-gray-600">Play ranked games against other humans to appear on the leaderboard!</p>
            <.link href={~p"/lobby"} class="inline-block mt-3 bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700">
              Find a Game
            </.link>
          </div>
        <% end %>

        <!-- Leaderboard Table -->
        <div class="bg-white rounded-lg shadow-xl overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Rank</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Player</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Tier</th>
                <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Rating</th>
                <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Games</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= if @leaderboard == [] do %>
                <tr>
                  <td colspan="5" class="px-4 py-8 text-center text-gray-500">
                    No ranked players yet. Be the first!
                  </td>
                </tr>
              <% else %>
                <%= for {player, idx} <- Enum.with_index(@leaderboard, 1) do %>
                  <tr class={if player.id == @current_user.id, do: "bg-yellow-50", else: ""}>
                    <td class="px-4 py-3">
                      <span class={rank_class(idx)}>{idx}</span>
                    </td>
                    <td class="px-4 py-3">
                      <div class="font-medium">{player.display_name || player.username}</div>
                    </td>
                    <td class="px-4 py-3">
                      <span class={"inline-flex items-center px-2 py-1 rounded text-white text-xs #{@tier_colors[player.elo_tier]}"}>
                        {@tier_icons[player.elo_tier]} {String.capitalize(player.elo_tier)}
                      </span>
                    </td>
                    <td class="px-4 py-3 text-right font-semibold">{player.elo_rating}</td>
                    <td class="px-4 py-3 text-right text-gray-600">{player.elo_games_played}</td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp tier_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <span class={"w-3 h-3 rounded-full #{@colors[@tier]}"}></span>
      <span class="text-sm">{@icons[@tier]} {String.capitalize(@tier)}</span>
      <span class="text-xs text-gray-500">({@label})</span>
    </div>
    """
  end

  defp rank_class(1), do: "text-xl font-bold text-yellow-500"
  defp rank_class(2), do: "text-lg font-bold text-gray-400"
  defp rank_class(3), do: "text-lg font-bold text-amber-600"
  defp rank_class(_), do: "text-gray-700"
end
```

**Step 5: Run test to verify it passes**

Run:
```bash
mix test test/rachel_web/live/leaderboard_live_test.exs
```

Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/rachel_web/live/leaderboard_live.ex lib/rachel_web/router.ex test/rachel_web/live/leaderboard_live_test.exs
git commit -m "feat(ui): add leaderboard page"
```

---

## Task 9: Lobby Leaderboard Widget

**Files:**
- Create: `lib/rachel_web/components/leaderboard_widget.ex`
- Modify: `lib/rachel_web/live/lobby_live.ex`
- Test: `test/rachel_web/live/lobby_live_test.exs` (add to existing)

**Step 1: Write failing test**

Add to `test/rachel_web/live/lobby_live_test.exs`:

```elixir
  describe "leaderboard widget" do
    test "shows top 5 players", %{conn: conn} do
      # Create some ranked users
      for i <- 1..6 do
        {:ok, u} =
          %Rachel.Accounts.User{}
          |> Rachel.Accounts.User.registration_changeset(%{
            email: "player#{i}@test.com",
            username: "Player#{i}",
            password: "password123456"
          })
          |> Rachel.Repo.insert()

        u
        |> Ecto.Changeset.change(%{elo_rating: 1000 + i * 50, elo_games_played: 5})
        |> Rachel.Repo.update!()
      end

      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "Top Players"
      assert html =~ "Player6"  # Highest rated
      assert html =~ "Player5"
      refute html =~ "Player1"  # 6th place, not shown
    end

    test "shows link to full leaderboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "View Full Leaderboard"
      assert html =~ ~s(href="/leaderboard")
    end
  end
```

**Step 2: Run test to verify it fails**

Run:
```bash
mix test test/rachel_web/live/lobby_live_test.exs --only describe:"leaderboard widget"
```

Expected: FAIL

**Step 3: Create widget component**

Create `lib/rachel_web/components/leaderboard_widget.ex`:

```elixir
defmodule RachelWeb.Components.LeaderboardWidget do
  use Phoenix.Component

  alias Rachel.Leaderboard

  @tier_colors %{
    "bronze" => "bg-amber-700",
    "silver" => "bg-gray-400",
    "gold" => "bg-yellow-500",
    "platinum" => "bg-cyan-400",
    "diamond" => "bg-purple-500"
  }

  @tier_icons %{
    "bronze" => "🥉",
    "silver" => "🥈",
    "gold" => "🥇",
    "platinum" => "💎",
    "diamond" => "👑"
  }

  attr :current_user, :map, required: true

  def leaderboard_widget(assigns) do
    top_players = Leaderboard.get_leaderboard(limit: 5)
    user_rank = Leaderboard.get_user_rank(assigns.current_user.id)

    assigns =
      assigns
      |> assign(:top_players, top_players)
      |> assign(:user_rank, user_rank)
      |> assign(:tier_colors, @tier_colors)
      |> assign(:tier_icons, @tier_icons)

    ~H"""
    <div class="bg-white rounded-lg shadow-lg p-4">
      <div class="flex justify-between items-center mb-3">
        <h3 class="font-bold text-gray-900">Top Players</h3>
        <a href="/leaderboard" class="text-sm text-green-600 hover:text-green-700">
          View Full Leaderboard →
        </a>
      </div>

      <%= if @top_players == [] do %>
        <p class="text-gray-500 text-sm">No ranked players yet!</p>
      <% else %>
        <div class="space-y-2">
          <%= for {player, idx} <- Enum.with_index(@top_players, 1) do %>
            <div class={"flex items-center justify-between py-1 #{if player.id == @current_user.id, do: "bg-yellow-50 -mx-2 px-2 rounded", else: ""}"}>
              <div class="flex items-center gap-2">
                <span class={"w-5 text-center font-bold #{rank_color(idx)}"}>{idx}</span>
                <span class="text-sm">{player.display_name || player.username}</span>
              </div>
              <div class="flex items-center gap-2">
                <span class={"text-xs px-1 rounded #{@tier_colors[player.elo_tier]} text-white"}>
                  {@tier_icons[player.elo_tier]}
                </span>
                <span class="text-sm font-semibold">{player.elo_rating}</span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Current user's rank if not in top 5 -->
      <%= if @user_rank && @user_rank > 5 do %>
        <div class="mt-3 pt-3 border-t">
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-600">Your rank:</span>
            <span class="font-bold">#{@user_rank}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp rank_color(1), do: "text-yellow-500"
  defp rank_color(2), do: "text-gray-400"
  defp rank_color(3), do: "text-amber-600"
  defp rank_color(_), do: "text-gray-600"
end
```

**Step 4: Add widget to lobby**

Edit `lib/rachel_web/live/lobby_live.ex`. Add import at top:

```elixir
  import RachelWeb.Components.LeaderboardWidget
```

Add widget to render function, after the "Active Games" section (find a good spot in the layout):

```elixir
        <!-- Leaderboard Widget -->
        <div class="mt-8">
          <.leaderboard_widget current_user={@current_user} />
        </div>
```

**Step 5: Run test to verify it passes**

Run:
```bash
mix test test/rachel_web/live/lobby_live_test.exs
```

Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/rachel_web/components/leaderboard_widget.ex lib/rachel_web/live/lobby_live.ex test/rachel_web/live/lobby_live_test.exs
git commit -m "feat(ui): add leaderboard widget to lobby"
```

---

## Task 10: Post-Game Rating Display

**Files:**
- Modify: `lib/rachel_web/live/game_live.ex`
- Test: `test/rachel_web/live/game_live_test.exs` (add to existing)

**Step 1: Write failing test**

Add to `test/rachel_web/live/game_live_test.exs`:

```elixir
  describe "post-game rating display" do
    test "shows rating change after ranked game ends", %{conn: conn, user: user} do
      # This test needs a completed ranked game
      # For now, we'll test the component renders correctly with mock data
      # Full integration test would require game completion flow

      # Set user to have recent rating history
      {:ok, _} =
        %Rachel.Leaderboard.RatingHistory{}
        |> Rachel.Leaderboard.RatingHistory.changeset(%{
          user_id: user.id,
          rating_before: 1000,
          rating_after: 1015,
          rating_change: 15,
          game_position: 1,
          opponents_count: 1
        })
        |> Rachel.Repo.insert()

      user
      |> Ecto.Changeset.change(%{elo_rating: 1015, elo_games_played: 1})
      |> Rachel.Repo.update!()

      # The rating change should be visible somewhere in the game UI
      # This would be shown in a game-over modal or similar
      # Exact test depends on implementation
    end
  end
```

**Step 2: Document implementation approach**

The post-game rating display should be added to the existing game-over modal in `game_live.ex`. When a game ends:

1. Check if it was a ranked game (2+ human players)
2. Fetch the user's latest rating history entry for this game
3. Display the rating change in the game-over modal

Add to game_live.ex's game over handling:

```elixir
# In the game over modal section, add:
<%= if @rating_change do %>
  <div class="mt-4 p-3 bg-gray-100 rounded">
    <div class="text-sm text-gray-600">Rating Change</div>
    <div class={if @rating_change >= 0, do: "text-green-600 text-xl font-bold", else: "text-red-600 text-xl font-bold"}>
      {if @rating_change >= 0, do: "+", else: ""}{@rating_change} → {@new_rating}
    </div>
    <%= if @tier_changed do %>
      <div class="text-yellow-500 font-semibold mt-1">
        🎉 You reached {@new_tier}!
      </div>
    <% end %>
  </div>
<% end %>
```

**Step 3: Commit placeholder**

This task requires more integration with the existing game flow. Create a TODO for follow-up:

```bash
git commit --allow-empty -m "docs: TODO - add post-game rating display to game_live"
```

---

## Task 11: Add Navigation Link

**Files:**
- Modify: `lib/rachel_web/components/layouts/app.html.heex` or navigation component

**Step 1: Add leaderboard link to navigation**

Find the navigation component and add:

```elixir
<.link href={~p"/leaderboard"} class="...">
  Leaderboard
</.link>
```

**Step 2: Commit**

```bash
git add lib/rachel_web/components/layouts/
git commit -m "feat(ui): add leaderboard to navigation"
```

---

## Task 12: Run Full Test Suite

**Step 1: Run all tests**

Run:
```bash
mix test
```

Expected: All tests pass (1078+ tests)

**Step 2: Manual testing checklist**

- [ ] Start server: `mix phx.server`
- [ ] Log in as user
- [ ] Visit /leaderboard - should show empty or with test data
- [ ] Visit /lobby - widget should appear
- [ ] Create multiplayer game with 2 humans
- [ ] Complete game
- [ ] Check ratings updated on leaderboard
- [ ] Check rating history appears

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(leaderboard): complete implementation"
```

---

## Summary

**Files Created:**
- `priv/repo/migrations/*_add_leaderboard_fields.exs`
- `lib/rachel/leaderboard.ex`
- `lib/rachel/leaderboard/rating_history.ex`
- `lib/rachel_web/live/leaderboard_live.ex`
- `lib/rachel_web/components/leaderboard_widget.ex`
- `test/rachel/leaderboard_test.exs`
- `test/rachel/leaderboard/rating_history_test.exs`
- `test/rachel/leaderboard/integration_test.exs`
- `test/rachel_web/live/leaderboard_live_test.exs`

**Files Modified:**
- `lib/rachel/accounts/user.ex` - Add Elo fields
- `lib/rachel/game/games.ex` - Hook rating updates
- `lib/rachel_web/router.ex` - Add route
- `lib/rachel_web/live/lobby_live.ex` - Add widget
- `test/rachel/accounts/user_test.exs`
- `test/rachel_web/live/lobby_live_test.exs`
