# Rachel Web

Phoenix/Elixir implementation of Rachel card game with LiveView for real-time gameplay and RUBP protocol server.

**Status:** ✅ Production-ready and deployed to Fly.io | 🎨 Currently polishing UI/UX

**Quick links:** [`CURRENT_STATUS.md`](CURRENT_STATUS.md) | [`TODO.md`](TODO.md) | [`UI_UX_IMPROVEMENTS.md`](UI_UX_IMPROVEMENTS.md)

## Features

- ✅ Full game rules implementation
- ✅ Phoenix LiveView for real-time updates
- ✅ RUBP protocol server for cross-platform play
- ✅ Canvas-based card graphics
- ✅ AI opponents with multiple difficulty levels
- ✅ WebSocket and TCP support

## Quick Start

### Using Docker

```bash
docker compose up
```

Visit http://localhost:4000

### Local Development

Requirements:
- Elixir 1.16+
- Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+

```bash
# Install dependencies
mix setup

# Start Phoenix server
mix phx.server
```

## Architecture

### Game Engine
- `lib/rachel/game/` - Core game logic
- `lib/rachel/game/rules.ex` - Rule enforcement
- `lib/rachel/game/cards.ex` - Card representations
- `lib/rachel/game/ai/` - AI opponents

### Protocol Server
- `lib/rachel/protocol/` - RUBP implementation
- TCP server on port 1982
- WebSocket bridge for web clients

### Web Interface
- `lib/rachel_web/live/` - LiveView components
- `assets/js/` - Canvas card rendering
- Real-time updates via Phoenix PubSub

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test
mix test test/rachel/game/rules_test.exs
```

## Deployment

### Production Docker

```bash
docker build -t rachel-web:latest .
docker run -p 4000:4000 -p 1982:1982 rachel-web:latest
```

### Fly.io Deployment

```bash
fly launch
fly deploy
```

## Network Play

### WebSocket (Web Clients)
- Connect to `ws://localhost:4000/socket`
- JavaScript client in `assets/js/socket.js`

### TCP (Native Clients)
- Connect to port 1982
- Implements RUBP v1.0 protocol
- See PROTOCOL.md for details

## AI Difficulty Levels

1. **Beginner** - Random valid moves
2. **Intermediate** - Basic strategy
3. **Advanced** - Card counting, defensive play
4. **Expert** - Optimal play, psychological modeling

## Development

### Code Structure

```
lib/
├── rachel/
│   ├── application.ex       # OTP application
│   ├── game/
│   │   ├── game.ex          # Game state machine
│   │   ├── rules.ex         # Rule enforcement
│   │   ├── cards.ex         # Card logic
│   │   ├── deck.ex          # Deck management
│   │   ├── player.ex        # Player state
│   │   └── ai/              # AI implementations
│   └── protocol/
│       ├── server.ex        # TCP server
│       ├── handler.ex       # RUBP handler
│       └── messages.ex      # Message encoding/decoding
└── rachel_web/
    ├── live/
    │   ├── game_live.ex     # Main game LiveView
    │   ├── lobby_live.ex    # Game lobby
    │   └── components/      # UI components
    └── channels/
        └── game_channel.ex  # WebSocket channel
```

### Adding Features

1. Create feature branch
2. Implement with tests
3. Update documentation
4. Submit PR with screenshots

## License

Part of the Rachel Multiverse Project