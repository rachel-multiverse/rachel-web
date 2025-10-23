# Rachel API Documentation

This document provides comprehensive API documentation for the Rachel application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Modules](#core-modules)
3. [Game Management API](#game-management-api)
4. [LiveView Interface](#liveview-interface)
5. [Binary Protocol](#binary-protocol)
6. [Error Handling](#error-handling)
7. [Type Specifications](#type-specifications)

## Architecture Overview

Rachel is built using Phoenix LiveView for real-time web gameplay and includes a binary protocol server for retro platform connections. The architecture follows these principles:

- **Separation of Concerns**: Game logic is separate from presentation and protocol layers
- **OTP Supervision**: Each game runs in its own supervised process
- **Real-time Updates**: LiveView provides push-based updates without polling
- **Cross-Platform**: Binary protocol allows diverse clients to connect

### Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface Layer                    │
│  ┌────────────────┐        ┌────────────────────────────┐  │
│  │  Web Browser   │        │  Retro Platform Clients    │  │
│  │  (LiveView)    │        │  (Binary Protocol)         │  │
│  └────────────────┘        └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌────────────────┐        ┌────────────────────────────┐  │
│  │ GameManager    │        │  Protocol Server           │  │
│  │ (High-level)   │        │  (Binary Messages)         │  │
│  └────────────────┘        └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                      Game Engine Layer                       │
│  ┌────────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │ GameEngine     │  │ AIPlayer    │  │ Rules          │  │
│  │ (GenServer)    │  │             │  │                │  │
│  └────────────────┘  └─────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                      State Layer                             │
│  ┌────────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │ GameState      │  │ Deck        │  │ Card           │  │
│  │ (Immutable)    │  │             │  │                │  │
│  └────────────────┘  └─────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Core Modules

### Rachel.GameManager

High-level API for game management. This is the primary entry point for most game operations.

**Location**: `lib/rachel/game_manager.ex`

**Purpose**: Provides a simplified, user-friendly API for creating and managing games

**Key Functions**:
- `create_game/1` - Create a new game
- `create_ai_game/3` - Create a game with AI opponents
- `get_game/1` - Retrieve game state
- `play_cards/4` - Play cards in a game
- `draw_cards/3` - Draw cards
- `nominate_suit/3` - Nominate a suit for Aces

### Rachel.Game.GameEngine

Lower-level game engine that manages game processes.

**Location**: `lib/rachel/game/game_engine.ex`

**Purpose**: GenServer that maintains game state and processes game actions

**Key Functions**:
- `start_link/1` - Start a game process
- `get_state/1` - Get current game state
- `play_cards/4` - Process card plays
- `draw_cards/3` - Process card draws
- `handle_turn_timeout/1` - Handle turn timeouts

### Rachel.Game.GameState

Immutable game state data structure.

**Location**: `lib/rachel/game/game_state.ex`

**Purpose**: Represents the complete state of a game at a point in time

**Key Functions**:
- `new/2` - Create new game state
- `start_game/1` - Transition to playing status
- `play_cards/4` - Pure function for playing cards
- `draw_cards/3` - Pure function for drawing cards
- `apply_card_effect/2` - Apply special card effects

### Rachel.Game.Rules

Game rules validation and enforcement.

**Location**: `lib/rachel/game/rules.ex`

**Purpose**: Validates moves according to game rules

**Key Functions**:
- `can_play_card?/3` - Check if a card can be played
- `can_stack?/2` - Check if cards can be stacked
- `must_play?/2` - Check if player must play (mandatory play rule)
- `calculate_penalty/1` - Calculate draw penalty

## Game Management API

### Creating Games

#### create_game/1

Creates a new game with the specified players.

```elixir
@spec create_game([player_spec()]) :: {:ok, String.t()} | {:error, term()}
```

**Player Specifications**:

```elixir
# Authenticated user
{:user, user_id :: integer(), name :: String.t()}

# Anonymous player
{:anonymous, name :: String.t()}

# AI player
{:ai, name :: String.t(), difficulty :: :easy | :medium | :hard}

# Simple string (backwards compatibility, treated as anonymous)
name :: String.t()
```

**Example**:

```elixir
# Create game with mix of player types
{:ok, game_id} = GameManager.create_game([
  {:user, 1, "Alice"},
  {:anonymous, "Bob"},
  {:ai, "Charlie", :medium},
  "David"
])
```

**Returns**:
- `{:ok, game_id}` - Success with unique game identifier
- `{:error, :invalid_player_count}` - Less than 2 or more than 8 players
- `{:error, reason}` - Other errors

#### create_ai_game/3

Convenience function to create a game with AI opponents.

```elixir
@spec create_ai_game(player_spec(), non_neg_integer(), atom()) ::
        {:ok, String.t()} | {:error, term()}
```

**Parameters**:
- `player` - The human player
- `num_ai` - Number of AI opponents (default: 3)
- `difficulty` - AI difficulty (`:easy`, `:medium`, `:hard`, default: `:medium`)

**Example**:

```elixir
# Create game with 3 medium AI opponents
{:ok, game_id} = GameManager.create_ai_game({:user, 1, "Alice"}, 3, :medium)

# Create game with 5 hard AI opponents
{:ok, game_id} = GameManager.create_ai_game("Bob", 5, :hard)
```

### Retrieving Game State

#### get_game/1

Retrieves the current state of a game.

```elixir
@spec get_game(String.t()) :: {:ok, GameState.t()} | {:error, :game_not_found}
```

**Example**:

```elixir
case GameManager.get_game(game_id) do
  {:ok, game} ->
    IO.inspect(game.status)  # :waiting, :playing, :finished
    IO.inspect(game.current_player_index)
    IO.inspect(game.discard_pile)

  {:error, :game_not_found} ->
    IO.puts("Game not found")
end
```

**Game State Structure**:

```elixir
%GameState{
  id: String.t(),
  status: :waiting | :playing | :finished,
  players: [Player.t()],
  current_player_index: non_neg_integer(),
  direction: :clockwise | :counter_clockwise,
  deck: [Card.t()],
  discard_pile: [Card.t()],
  nominated_suit: atom() | nil,
  winner_id: String.t() | nil,
  turn_number: non_neg_integer(),
  last_action: String.t() | nil
}
```

#### get_game_info/1

Retrieves public game information suitable for listing.

```elixir
@spec get_game_info(String.t()) :: {:ok, map()} | {:error, :game_not_found}
```

**Example**:

```elixir
{:ok, info} = GameManager.get_game_info(game_id)
# %{
#   id: "game-123",
#   status: :playing,
#   player_count: 4,
#   current_player: "Alice",
#   turn_number: 15
# }
```

### Playing Cards

#### play_cards/4

Plays one or more cards in a game.

```elixir
@spec play_cards(String.t(), String.t(), [Card.t()], atom() | nil) ::
        {:ok, GameState.t()} | {:error, term()}
```

**Parameters**:
- `game_id` - The game identifier
- `player_id` - The player making the move
- `cards` - List of cards to play (can be multiple for stacking)
- `nominated_suit` - Suit nomination if playing Ace(s), otherwise `nil`

**Example**:

```elixir
# Play a single card
card = %Card{suit: :hearts, rank: :seven}
{:ok, game} = GameManager.play_cards(game_id, player_id, [card], nil)

# Play stacked cards (three 7s)
cards = [
  %Card{suit: :hearts, rank: :seven},
  %Card{suit: :diamonds, rank: :seven},
  %Card{suit: :clubs, rank: :seven}
]
{:ok, game} = GameManager.play_cards(game_id, player_id, cards, nil)

# Play Ace with suit nomination
ace = %Card{suit: :spades, rank: :ace}
{:ok, game} = GameManager.play_cards(game_id, player_id, [ace], :hearts)
```

**Errors**:
- `{:error, :not_your_turn}` - Not the current player
- `{:error, :invalid_play}` - Cards don't match discard pile
- `{:error, :cannot_stack}` - Cards cannot be stacked
- `{:error, :must_nominate_suit}` - Ace requires suit nomination
- `{:error, :cards_not_in_hand}` - Player doesn't have those cards

### Drawing Cards

#### draw_cards/3

Draws cards for a player.

```elixir
@spec draw_cards(String.t(), String.t(), atom()) ::
        {:ok, GameState.t()} | {:error, term()}
```

**Parameters**:
- `game_id` - The game identifier
- `player_id` - The player drawing cards
- `reason` - Reason for drawing (`:cannot_play`, `:attack_penalty`, `:voluntary`)

**Example**:

```elixir
# Draw when cannot play
{:ok, game} = GameManager.draw_cards(game_id, player_id, :cannot_play)

# Draw as penalty from attack card
{:ok, game} = GameManager.draw_cards(game_id, player_id, :attack_penalty)
```

**Rules**:
- Cannot draw if valid cards exist in hand (mandatory play rule)
- Attack penalties draw multiple cards based on card type
- Drawing ends your turn

### Suit Nomination

#### nominate_suit/3

Nominates a suit after playing an Ace.

```elixir
@spec nominate_suit(String.t(), String.t(), atom()) ::
        {:ok, GameState.t()} | {:error, term()}
```

**Parameters**:
- `game_id` - The game identifier
- `player_id` - The player nominating
- `suit` - The suit to nominate (`:hearts`, `:diamonds`, `:clubs`, `:spades`)

**Example**:

```elixir
{:ok, game} = GameManager.nominate_suit(game_id, player_id, :hearts)
```

**Note**: This is an alternative to nominating when playing the Ace. Prefer passing `nominated_suit` to `play_cards/4`.

## LiveView Interface

### RachelWeb.GameLive

The main LiveView module for game interface.

**Location**: `lib/rachel_web/live/game_live.ex`

#### Mount Parameters

```elixir
# Route: /game/:game_id
%{
  "game_id" => String.t()  # The game to join/display
}
```

#### Socket Assigns

```elixir
%{
  game_id: String.t(),
  game: GameState.t() | nil,
  player_id: String.t() | nil,
  current_user: User.t() | nil,
  error: String.t() | nil,
  selected_cards: [Card.t()],
  show_suit_selector: boolean()
}
```

#### Events

**"select_card"** - Select a card from hand
```elixir
%{"card" => %{"suit" => "hearts", "rank" => "7"}}
```

**"play_selected"** - Play selected cards
```elixir
%{} or %{"suit" => "hearts"}  # suit only needed for Aces
```

**"draw_cards"** - Draw cards
```elixir
%{}
```

**"skip_turn"** - Skip turn (when allowed)
```elixir
%{}
```

#### PubSub Topics

Games broadcast updates via Phoenix.PubSub:

```elixir
# Subscribe to game updates
Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

# Broadcasted messages
{:game_updated, game_state}
{:turn_changed, current_player_index}
{:game_finished, winner_id}
```

## Binary Protocol

The binary protocol allows retro platforms to connect and play.

**Location**: `lib/rachel/protocol/`

### Message Format

All messages are exactly 64 bytes in big-endian byte order.

```
Byte 0: Message Type
Bytes 1-63: Message-specific data
```

### Message Types

#### Client → Server

**0x01: CONNECT**
```
Format: [0x01, player_name (32 bytes), ...]
```

**0x02: JOIN_GAME**
```
Format: [0x02, game_id (16 bytes), ...]
```

**0x03: PLAY_CARDS**
```
Format: [0x03, card_count, card1_data, card2_data, ..., suit_nomination]
```

**0x04: DRAW_CARDS**
```
Format: [0x04, reason, ...]
```

#### Server → Client

**0x81: WELCOME**
```
Format: [0x81, player_id (16 bytes), session_key (32 bytes), ...]
```

**0x82: GAME_STATE**
```
Format: [0x82, status, current_player, hand_size, discard_top, ...]
```

**0x83: TURN_UPDATE**
```
Format: [0x83, current_player_index, cards_drawn, ...]
```

**0x84: GAME_OVER**
```
Format: [0x84, winner_id (16 bytes), ...]
```

**0xFF: ERROR**
```
Format: [0xFF, error_code, error_message (62 bytes)]
```

### Protocol Server

**Starting the server**:

```elixir
# Configured in config/runtime.exs
config :rachel, binary_protocol_port: 6502
```

Server automatically starts with the application.

**Connecting a client**:

```
1. TCP connect to port 6502
2. Send CONNECT message with player name
3. Receive WELCOME with player_id and session_key
4. Send JOIN_GAME or CREATE_GAME
5. Exchange game messages
```

See `PROTOCOL.md` for complete specification.

## Error Handling

### Error Return Format

All functions return tagged tuples:

```elixir
{:ok, result}      # Success
{:error, reason}   # Failure with reason atom
{:error, {reason, details}}  # Failure with additional context
```

### Common Error Reasons

**Game Not Found**:
```elixir
{:error, :game_not_found}
```

**Invalid Player Count**:
```elixir
{:error, :invalid_player_count}
```

**Not Your Turn**:
```elixir
{:error, :not_your_turn}
```

**Invalid Play**:
```elixir
{:error, :invalid_play}
{:error, {:invalid_play, "Card doesn't match discard pile"}}
```

**Cannot Stack**:
```elixir
{:error, :cannot_stack}
```

**Must Nominate Suit**:
```elixir
{:error, :must_nominate_suit}
```

**Cards Not in Hand**:
```elixir
{:error, :cards_not_in_hand}
```

### Error Handling Pattern

```elixir
case GameManager.play_cards(game_id, player_id, cards, nil) do
  {:ok, game} ->
    # Success - process new game state
    handle_game_update(game)

  {:error, :not_your_turn} ->
    # Not current player
    {:error, "Wait for your turn"}

  {:error, :invalid_play} ->
    # Invalid card choice
    {:error, "That card cannot be played"}

  {:error, reason} ->
    # Other error
    {:error, "Game error: #{inspect(reason)}"}
end
```

## Type Specifications

### Card Types

```elixir
@type suit :: :hearts | :diamonds | :clubs | :spades
@type rank :: :two | :three | :four | :five | :six | :seven |
              :eight | :nine | :ten | :jack | :queen | :king | :ace

@type t :: %Card{
  suit: suit(),
  rank: rank()
}
```

### Player Types

```elixir
@type player_type :: :user | :anonymous | :ai

@type t :: %Player{
  id: String.t(),
  name: String.t(),
  type: player_type(),
  hand: [Card.t()],
  user_id: integer() | nil,
  ai_difficulty: atom() | nil,
  connected: boolean()
}
```

### Game State Types

```elixir
@type status :: :waiting | :playing | :finished
@type direction :: :clockwise | :counter_clockwise

@type t :: %GameState{
  id: String.t(),
  status: status(),
  players: [Player.t()],
  current_player_index: non_neg_integer(),
  direction: direction(),
  deck: [Card.t()],
  discard_pile: [Card.t()],
  nominated_suit: suit() | nil,
  winner_id: String.t() | nil,
  turn_number: non_neg_integer(),
  last_action: String.t() | nil,
  attack_stack: non_neg_integer(),
  skip_stack: non_neg_integer()
}
```

---

## Additional Resources

- **Game Rules**: See `GAME_RULES.md` for complete game rules
- **Protocol Specification**: See `PROTOCOL.md` for binary protocol details
- **Contributing**: See `CONTRIBUTING.md` for development guidelines
- **Source Code**: Inline documentation in source files

## Support

For API questions or issues:
- Check the inline documentation with `h ModuleName` in IEx
- Review test files for usage examples
- Open an issue on GitHub
- Consult the CONTRIBUTING.md guide
