# Leaderboard Design

**Date:** 2025-11-27
**Status:** Approved

## Overview

Add an Elo-based ranking system with leaderboards to Rachel. Only human-vs-human games affect ratings. AI games remain unranked practice.

## Elo System

### Core Rules

- **Starting rating:** 1000
- **K-factor:** 32 for first 30 games (provisional), then 16 (established)
- **Scope:** Only games with 2+ human players are ranked
- **Multiplayer handling:** Pairwise calculation (4-player game = 6 pairwise matchups)

### Pairwise Calculation

For each pair of human players in a game:

```
Expected = 1 / (1 + 10^((opponent_elo - player_elo) / 400))
Actual = 1.0 (won), 0.5 (tied), 0.0 (lost)
Change = K × (Actual - Expected)
```

Player's total rating change is the sum of all pairwise results.

### Tiers

| Tier     | Rating Range |
|----------|--------------|
| Bronze   | < 900        |
| Silver   | 900 - 1099   |
| Gold     | 1100 - 1299  |
| Platinum | 1300 - 1499  |
| Diamond  | 1500+        |

## Data Model

### New fields on `users` table

```elixir
field :elo_rating, :integer, default: 1000
field :elo_games_played, :integer, default: 0
field :elo_tier, :string, default: "bronze"
```

### New `rating_history` table

```elixir
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
```

## UI Components

### 1. Leaderboard Page (`/leaderboard`)

- Tier legend with icons/colours
- Top 100 table: rank, avatar, name, tier badge, rating, games played, win rate
- "Your Position" card (visible even if outside top 100)
- Recent trend indicator (+/- last 5 games)

### 2. Lobby Widget

- Top 5 mini-leaderboard
- Current user's rank and tier badge
- Link to full leaderboard

### 3. Post-Game Display

- Rating change shown after ranked games: "+15 → 1047"
- Tier promotion celebration when crossing thresholds

### 4. Profile Integration

- Tier badge on profile/stats page
- Rating history sparkline or simple chart

## Implementation

### New Files

- `lib/rachel/leaderboard.ex` - Context module
- `lib/rachel/leaderboard/rating_history.ex` - Schema
- `lib/rachel_web/live/leaderboard_live.ex` - Full page
- `lib/rachel_web/components/leaderboard_widget.ex` - Lobby widget
- Migration for schema changes

### Modified Files

- `lib/rachel/game/game_engine.ex` - Trigger rating calculation on game end
- `lib/rachel_web/live/lobby_live.ex` - Add widget
- `lib/rachel_web/live/game_live.ex` - Show post-game rating change
- `lib/rachel_web/live/stats_live.ex` - Add tier badge and rating graph
- `lib/rachel_web/router.ex` - Add `/leaderboard` route

### Technical Notes

- Elo calculation and history insert happen in a single transaction
- Tier recalculated on every rating update
- Index on `users.elo_rating DESC` for leaderboard queries
- Optional: PubSub broadcast on rating changes for live widget updates
