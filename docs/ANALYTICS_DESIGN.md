# Game Analytics Design

## Overview

Track game events and player behavior to understand:
- Which strategies win most often
- Most/least played cards
- Game duration and turn patterns
- AI difficulty effectiveness
- Player engagement metrics

## Events to Track

### Game Events
- `game_started` - When a game begins
- `game_finished` - When a game ends (with winner)
- `game_abandoned` - When all players disconnect before finish

### Turn Events
- `card_played` - Each card play with context
- `cards_drawn` - When cards are drawn (reason: attack/cannot_play)
- `turn_skipped` - When turn is skipped by card effect
- `direction_reversed` - When Queen reverses direction
- `suit_nominated` - When Ace nominates suit

### Player Events
- `player_joined` - Player enters game
- `player_disconnected` - Player loses connection
- `player_reconnected` - Player reconnects
- `player_went_out` - Player empties hand

## Data Schema

### game_stats table
```sql
CREATE TABLE game_stats (
  id BIGSERIAL PRIMARY KEY,
  game_id TEXT NOT NULL,
  started_at TIMESTAMP NOT NULL,
  finished_at TIMESTAMP,
  duration_seconds INTEGER,
  total_turns INTEGER,
  player_count INTEGER NOT NULL,
  ai_count INTEGER NOT NULL,
  winner_type TEXT, -- 'user', 'anonymous', 'ai'
  winner_ai_difficulty TEXT, -- 'easy', 'medium', 'hard' if AI won
  abandoned BOOLEAN DEFAULT FALSE,
  deck_count INTEGER DEFAULT 1,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX game_stats_started_at_idx ON game_stats(started_at DESC);
CREATE INDEX game_stats_winner_type_idx ON game_stats(winner_type);
CREATE INDEX game_stats_duration_idx ON game_stats(duration_seconds);
```

### card_play_stats table
```sql
CREATE TABLE card_play_stats (
  id BIGSERIAL PRIMARY KEY,
  game_id TEXT NOT NULL,
  player_type TEXT NOT NULL, -- 'user', 'anonymous', 'ai'
  ai_difficulty TEXT, -- if AI player
  turn_number INTEGER NOT NULL,
  cards_played JSONB NOT NULL, -- [{suit: "hearts", rank: "ace"}, ...]
  was_stacked BOOLEAN DEFAULT FALSE,
  stack_size INTEGER DEFAULT 1,
  nominated_suit TEXT, -- if Ace was played
  resulted_in_win BOOLEAN DEFAULT FALSE,
  played_at TIMESTAMP NOT NULL,
  inserted_at TIMESTAMP NOT NULL
);

CREATE INDEX card_play_stats_game_id_idx ON card_play_stats(game_id);
CREATE INDEX card_play_stats_played_at_idx ON card_play_stats(played_at DESC);
CREATE INDEX card_play_stats_cards_idx ON card_play_stats USING gin(cards_played);
```

### card_draw_stats table
```sql
CREATE TABLE card_draw_stats (
  id BIGSERIAL PRIMARY KEY,
  game_id TEXT NOT NULL,
  player_type TEXT NOT NULL,
  ai_difficulty TEXT,
  turn_number INTEGER NOT NULL,
  cards_drawn INTEGER NOT NULL,
  reason TEXT NOT NULL, -- 'cannot_play', 'attack_penalty', 'voluntary'
  attack_type TEXT, -- '2', '7', 'black_jack' if attack penalty
  drawn_at TIMESTAMP NOT NULL,
  inserted_at TIMESTAMP NOT NULL
);

CREATE INDEX card_draw_stats_game_id_idx ON card_draw_stats(game_id);
CREATE INDEX card_draw_stats_reason_idx ON card_draw_stats(reason);
```

## Analytics Queries

### Win Rate by Player Type
```sql
SELECT
  winner_type,
  COUNT(*) as wins,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as win_percentage
FROM game_stats
WHERE finished_at IS NOT NULL
  AND abandoned = false
GROUP BY winner_type
ORDER BY wins DESC;
```

### AI Difficulty Effectiveness
```sql
SELECT
  winner_ai_difficulty,
  COUNT(*) as wins,
  ROUND(AVG(total_turns), 2) as avg_turns_to_win,
  ROUND(AVG(duration_seconds), 2) as avg_duration_seconds
FROM game_stats
WHERE winner_type = 'ai'
  AND winner_ai_difficulty IS NOT NULL
  AND abandoned = false
GROUP BY winner_ai_difficulty
ORDER BY wins DESC;
```

### Most Played Cards
```sql
SELECT
  card->>'rank' as rank,
  card->>'suit' as suit,
  COUNT(*) as times_played,
  SUM(CASE WHEN resulted_in_win THEN 1 ELSE 0 END) as led_to_wins,
  ROUND(
    SUM(CASE WHEN resulted_in_win THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    2
  ) as win_rate_percentage
FROM card_play_stats,
     jsonb_array_elements(cards_played) as card
GROUP BY card->>'rank', card->>'suit'
ORDER BY times_played DESC;
```

### Card Stacking Frequency
```sql
SELECT
  stack_size,
  COUNT(*) as occurrences,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM card_play_stats
WHERE was_stacked = true
GROUP BY stack_size
ORDER BY stack_size;
```

### Draw Reasons Distribution
```sql
SELECT
  reason,
  attack_type,
  SUM(cards_drawn) as total_cards_drawn,
  COUNT(*) as occurrences,
  ROUND(AVG(cards_drawn), 2) as avg_cards_per_draw
FROM card_draw_stats
GROUP BY reason, attack_type
ORDER BY total_cards_drawn DESC;
```

### Average Game Metrics
```sql
SELECT
  player_count,
  COUNT(*) as games_played,
  ROUND(AVG(duration_seconds), 2) as avg_duration_seconds,
  ROUND(AVG(total_turns), 2) as avg_turns,
  ROUND(AVG(total_turns::float / player_count), 2) as avg_turns_per_player
FROM game_stats
WHERE finished_at IS NOT NULL
  AND abandoned = false
GROUP BY player_count
ORDER BY player_count;
```

### Peak Play Times (Hourly)
```sql
SELECT
  EXTRACT(HOUR FROM started_at) as hour_of_day,
  COUNT(*) as games_started,
  COUNT(DISTINCT DATE(started_at)) as unique_days
FROM game_stats
WHERE started_at > NOW() - INTERVAL '30 days'
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

### Card Effect Usage
```sql
-- Suit nominations (Aces)
SELECT
  nominated_suit,
  COUNT(*) as times_nominated,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM card_play_stats
WHERE nominated_suit IS NOT NULL
GROUP BY nominated_suit
ORDER BY times_nominated DESC;

-- Attack card usage
SELECT
  attack_type,
  COUNT(*) as times_used,
  SUM(cards_drawn) as total_cards_forced_to_draw
FROM card_draw_stats
WHERE reason = 'attack_penalty'
GROUP BY attack_type
ORDER BY times_used DESC;
```

## Dashboard Views

### Overview Page
- Total games played (last 7/30/90 days)
- Active players (unique users/sessions)
- Average game duration
- Win distribution by player type
- Games per hour (line chart)

### Card Statistics Page
- Most/least played cards (bar chart)
- Card win rates (when played leads to win)
- Stack frequency distribution
- Special card effectiveness (2s, 7s, Jacks, Queens, Aces)

### Player Behavior Page
- Win rate by player type and AI difficulty
- Average turns to win
- Draw reasons distribution (pie chart)
- Abandoned game rate

### Performance Page
- Average game duration by player count
- Turns per game distribution
- Time to first card play
- Reconnection frequency

## Implementation Notes

### Event Capture
Events should be captured asynchronously to not block game operations:
1. Game engine broadcasts Telemetry events
2. Analytics module subscribes to events
3. Events queued for batch insertion
4. Periodic flush to database (every 5 seconds or 100 events)

### Privacy Considerations
- Don't store PII (user emails, IP addresses)
- Store only user IDs for authenticated users
- Anonymous players get no identifier
- AI players clearly marked

### Performance
- Use batch inserts for high-volume events (card plays)
- Aggregate daily/weekly for historical analysis
- Partition tables by date if volume gets high
- Consider moving old data to cold storage after 90 days

### Retention Policy
- Keep detailed event data for 90 days
- Aggregate and keep summary stats indefinitely
- Delete abandoned games older than 30 days
