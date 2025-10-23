# Contributing to Rachel

Thank you for your interest in contributing to Rachel! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Coding Standards](#coding-standards)
6. [Testing Guidelines](#testing-guidelines)
7. [Commit Message Guidelines](#commit-message-guidelines)
8. [Pull Request Process](#pull-request-process)
9. [Documentation](#documentation)
10. [Getting Help](#getting-help)

## Code of Conduct

By participating in this project, you agree to:
- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- Elixir 1.18+ and OTP 27+
- PostgreSQL 16+
- Node.js 18+ (for asset compilation)
- Git

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/rachel-web.git
   cd rachel-web
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   npm install --prefix assets
   ```

3. **Set up the database**
   ```bash
   mix ecto.setup
   ```

4. **Start the development server**
   ```bash
   iex -S mix phx.server
   ```

5. **Visit the application**
   Open [http://localhost:4000](http://localhost:4000) in your browser

## How to Contribute

### Reporting Bugs

Before creating a bug report:
- Check the issue tracker to avoid duplicates
- Gather information about the bug (steps to reproduce, expected vs actual behavior)
- Include relevant system information (OS, Elixir/OTP versions, browser)

When creating a bug report, include:
- A clear, descriptive title
- Detailed steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots or error messages if applicable
- Environment information

### Suggesting Features

Feature requests are welcome! When suggesting a feature:
- Check if it aligns with the project goals
- Provide a clear use case
- Describe the proposed solution
- Consider alternatives you've thought of

### Contributing Code

1. **Find or create an issue** to track your work
2. **Fork the repository** and create a new branch
3. **Make your changes** following our coding standards
4. **Write or update tests** for your changes
5. **Update documentation** as needed
6. **Submit a pull request** following our PR guidelines

## Coding Standards

### Elixir Code Style

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with a few project-specific conventions:

#### General Guidelines

- Use `mix format` before committing
- Run `mix credo` to check code quality
- Aim for functions with a single responsibility
- Keep modules focused and cohesive
- Prefer pattern matching over conditional logic

#### Naming Conventions

```elixir
# Module names: PascalCase
defmodule Rachel.Game.GameState do
end

# Function names: snake_case
def create_game(players) do
end

# Variable names: snake_case
game_state = GameState.new(players)

# Private functions: prefix with _
defp _validate_player(player) do
end

# Constants: @moduledoc attributes
@default_hand_size 7
```

#### Documentation

Every public function should have a `@doc` string:

```elixir
@doc """
Creates a new game with the specified players.

## Parameters

  - `players` - List of player names or player specs
  - `opts` - Optional keyword list of options

## Returns

  - `{:ok, game_id}` on success
  - `{:error, reason}` on failure

## Examples

    iex> GameManager.create_game(["Alice", "Bob"])
    {:ok, "game-123"}
"""
@spec create_game([String.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
def create_game(players, opts \\ []) do
  # Implementation
end
```

#### Type Specifications

Add `@spec` for all public functions:

```elixir
@spec play_cards(String.t(), String.t(), [Card.t()], atom() | nil) ::
        {:ok, GameState.t()} | {:error, term()}
def play_cards(game_id, player_id, cards, nominated_suit) do
  # Implementation
end
```

### LiveView Conventions

```elixir
defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  # Lifecycle callbacks first
  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket}
  end

  # Event handlers
  @impl true
  def handle_event("play_cards", %{"cards" => cards}, socket) do
    # Handle event
  end

  # Helper functions last
  defp assign_game(socket, game) do
    assign(socket, :game, game)
  end
end
```

### CSS/Styling

- Use Tailwind CSS utility classes
- Group related utilities together
- Use semantic class names for custom components
- Follow mobile-first responsive design

```html
<div class="flex flex-col items-center justify-center min-h-screen bg-gray-100 p-4 md:p-8">
  <div class="w-full max-w-4xl bg-white rounded-lg shadow-lg">
    <!-- Content -->
  </div>
</div>
```

## Testing Guidelines

### Writing Tests

- Write tests for all new features
- Update tests when modifying existing features
- Aim for high test coverage (80%+ is good)
- Test edge cases and error conditions

### Test Organization

```elixir
defmodule Rachel.GameManagerTest do
  use Rachel.DataCase, async: true

  alias Rachel.GameManager

  describe "create_game/1" do
    test "creates a game with valid players" do
      assert {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      assert is_binary(game_id)
    end

    test "returns error with fewer than 2 players" do
      assert {:error, _reason} = GameManager.create_game(["Alice"])
    end
  end

  describe "play_cards/4" do
    setup do
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob"])
      %{game_id: game_id}
    end

    test "allows valid card play", %{game_id: game_id} do
      # Test implementation
    end
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/rachel/game_manager_test.exs

# Run specific test
mix test test/rachel/game_manager_test.exs:42

# Run with coverage
mix coveralls
mix coveralls.html  # Generate HTML report
```

### LiveView Testing

```elixir
defmodule RachelWeb.GameLiveTest do
  use RachelWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders game page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/game/test-game-1")

    assert render(view) =~ "Game Room"
  end

  test "plays cards when clicked", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/game/test-game-1")

    view
    |> element("#card-5H")
    |> render_click()

    assert render(view) =~ "Card played"
  end
end
```

## Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic changes)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD changes

### Examples

```
feat(game): Add support for custom rule variations

Allow players to enable/disable specific card effects when creating a game.

Closes #123
```

```
fix(ui): Correct card overlap in mobile view

Cards were overlapping in hand display on screens < 640px.
Updated flex layout to prevent overlap.

Fixes #456
```

```
docs(api): Document GameManager public API

Added comprehensive @doc and @spec for all public functions.
```

### Commit Message Rules

- Use the imperative mood ("Add feature" not "Added feature")
- First line should be 50 characters or less
- Body should wrap at 72 characters
- Separate subject from body with a blank line
- Reference issues and PRs in the footer

## Pull Request Process

### Before Submitting

1. **Run the full test suite**
   ```bash
   mix test
   mix credo
   mix dialyzer
   ```

2. **Format your code**
   ```bash
   mix format
   ```

3. **Update documentation**
   - Add/update @doc strings for public functions
   - Update README if adding features
   - Add examples where helpful

4. **Update CHANGELOG** (if applicable)

### Submitting a Pull Request

1. **Create a descriptive title**
   - Follow conventional commit format
   - Example: `feat(game): Add tournament mode`

2. **Fill out the PR template**
   - Describe what changed and why
   - Link to related issues
   - Include screenshots for UI changes
   - List breaking changes (if any)

3. **Request review**
   - Tag relevant maintainers
   - Wait for CI checks to pass

### PR Review Process

- Maintainers will review your PR within 1-3 business days
- Address review comments by pushing new commits
- Once approved, a maintainer will merge your PR
- PRs that don't pass CI or have unresolved comments won't be merged

## Documentation

### Code Documentation

- Document all public functions with `@doc`
- Include `@spec` type specifications
- Add usage examples in docstrings
- Explain complex algorithms or business logic

### README Updates

Update the README when:
- Adding new features users should know about
- Changing installation or setup procedures
- Modifying configuration options
- Adding new dependencies

### API Documentation

Public API modules should include:
- Module-level `@moduledoc` explaining purpose
- Function-level `@doc` with parameters and return values
- `@spec` type specifications
- Usage examples

Example:

```elixir
defmodule Rachel.GameManager do
  @moduledoc """
  High-level API for managing Rachel games.

  This module provides functions for creating games, managing game state,
  and performing game actions like playing cards and drawing.

  ## Examples

      # Create a new game
      {:ok, game_id} = GameManager.create_game(["Alice", "Bob", "Charlie"])

      # Play cards
      {:ok, _game} = GameManager.play_cards(game_id, "alice-id", [card1, card2], nil)

      # Draw cards
      {:ok, _game} = GameManager.draw_cards(game_id, "alice-id", :cannot_play)
  """

  @doc """
  Creates a new game with the given players.

  Players can be specified as:
  - `{:user, user_id, name}` for authenticated users
  - `{:anonymous, name}` for anonymous players
  - `{:ai, name, difficulty}` for AI players
  - Plain strings (treated as anonymous players)

  ## Parameters

    - `players` - List of 2-8 player specifications

  ## Returns

    - `{:ok, game_id}` - Game created successfully
    - `{:error, :invalid_player_count}` - Not enough players
    - `{:error, reason}` - Other errors

  ## Examples

      iex> GameManager.create_game(["Alice", "Bob"])
      {:ok, "game-abc123"}

      iex> GameManager.create_game([{:user, 1, "Alice"}, {:ai, "Bob", :easy}])
      {:ok, "game-def456"}

      iex> GameManager.create_game(["Alice"])
      {:error, :invalid_player_count}
  """
  @spec create_game([player_spec()]) :: {:ok, String.t()} | {:error, term()}
  def create_game(players) do
    # Implementation
  end
end
```

## Getting Help

### Resources

- **Documentation**: Check the [README](README.md) and inline documentation
- **Issues**: Browse [existing issues](https://github.com/yourusername/rachel-web/issues)
- **Discussions**: Ask questions in [GitHub Discussions](https://github.com/yourusername/rachel-web/discussions)

### Questions?

If you have questions about:
- **Code**: Open a discussion or comment on a relevant issue
- **Features**: Check existing feature requests or create a new one
- **Bugs**: Search issues first, then create a bug report if needed

### Development Help

Stuck on something? Try:
1. Reading the relevant source code and tests
2. Checking the Elixir/Phoenix documentation
3. Searching existing issues and discussions
4. Asking in the project discussions

---

## Thank You!

Your contributions make Rachel better for everyone. We appreciate your time and effort in making this project successful!
