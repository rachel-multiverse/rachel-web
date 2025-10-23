# Generating Documentation

This guide explains how to generate and view the Rachel project documentation.

## Prerequisites

ExDoc is already configured as a development dependency. Ensure dependencies are installed:

```bash
mix deps.get
```

## Generating Documentation

### Generate HTML Documentation

```bash
# Generate documentation in doc/ directory
mix docs

# Output:
# Compiling X files (.ex)
# Generating docs...
# View documentation at doc/index.html
```

The documentation will be generated in the `doc/` directory.

### View Documentation

**Option 1: Open in Browser**
```bash
# macOS
open doc/index.html

# Linux
xdg-open doc/index.html

# Windows
start doc/index.html
```

**Option 2: Use a Local Server**
```bash
# Using Python
python3 -m http.server 8000 --directory doc

# Using PHP
php -S localhost:8000 -t doc

# Then visit: http://localhost:8000
```

## Documentation Structure

The generated documentation includes:

### 1. Guides

Located in the sidebar under "Pages":

- **Game Documentation**
  - Game Rules - Complete rules for the Rachel card game
  - Protocol Specification - Binary protocol for retro platforms

- **Development**
  - API Reference - Public API documentation
  - Contributing Guide - How to contribute
  - Dependency Updates - Automated update workflow

- **Operations**
  - Deployment Guide - Production deployment
  - Performance Benchmarking - Load testing and benchmarks
  - Uptime Monitoring - Health checks and monitoring

### 2. Module Documentation

Organized into logical groups:

- **Game Engine** - Core game logic and state management
- **Game Management** - High-level game operations
- **Web Interface** - LiveView components
- **Binary Protocol** - Protocol server and handlers

### 3. Search

Use the search box (top right) to find:
- Modules
- Functions
- Types
- Documentation content

## Customizing Documentation

### Adding New Guides

1. **Create a markdown file**
   ```bash
   echo "# My Guide" > docs/my-guide.md
   ```

2. **Add to mix.exs**
   ```elixir
   extras: [
     # ... existing extras ...
     "docs/my-guide.md": [title: "My Guide Title"]
   ]
   ```

3. **Add to a group (optional)**
   ```elixir
   groups_for_extras: [
     "Development": ["docs/my-guide.md"]
   ]
   ```

4. **Regenerate docs**
   ```bash
   mix docs
   ```

### Module Documentation

Ensure all public modules have `@moduledoc`:

```elixir
defmodule Rachel.MyModule do
  @moduledoc """
  Brief description of what this module does.

  ## Usage

      iex> MyModule.do_something()
      :ok

  ## Examples

  More detailed examples here.
  """

  # Module code...
end
```

### Function Documentation

Add `@doc` and `@spec` for all public functions:

```elixir
@doc """
Brief description of what this function does.

## Parameters

  - `param1` - Description of first parameter
  - `param2` - Description of second parameter

## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on failure

## Examples

    iex> my_function("test", 42)
    {:ok, %Result{}}

    iex> my_function("", 0)
    {:error, :invalid_input}
"""
@spec my_function(String.t(), integer()) :: {:ok, term()} | {:error, atom()}
def my_function(param1, param2) do
  # Implementation
end
```

### Adding Code Examples

Examples in documentation are tested with ExUnit:

```elixir
@doc """
Examples:

    iex> MyModule.add(1, 2)
    3

    iex> MyModule.add(5, 10)
    15
"""
def add(a, b), do: a + b
```

Run doctest:
```bash
mix test --only doctest
```

## Publishing Documentation

### To GitHub Pages

1. **Generate docs**
   ```bash
   mix docs
   ```

2. **Push to gh-pages branch**
   ```bash
   # Install ghp-import if needed
   pip install ghp-import

   # Push docs to gh-pages
   ghp-import -n -p doc
   ```

3. **Configure GitHub Pages**
   - Go to repo Settings → Pages
   - Source: gh-pages branch
   - Save

4. **Access docs**
   ```
   https://yourusername.github.io/rachel-web/
   ```

### To Hex.pm

If publishing as a Hex package:

1. **Update mix.exs**
   ```elixir
   def project do
     [
       # ... existing config ...
       description: "Strategic card game engine and server",
       package: package()
     ]
   end

   defp package do
     [
       licenses: ["MIT"],
       links: %{"GitHub" => "https://github.com/yourusername/rachel-web"}
     ]
   end
   ```

2. **Publish**
   ```bash
   mix hex.publish
   ```

Documentation is automatically published to HexDocs.

## CI Integration

### Generate Docs in CI

Add to `.github/workflows/docs.yml`:

```yaml
name: Documentation

on:
  push:
    branches: [ main ]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '27'

      - name: Install dependencies
        run: mix deps.get

      - name: Generate documentation
        run: mix docs

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./doc
```

### Check Documentation in PRs

Add documentation checks to CI:

```yaml
- name: Check documentation
  run: mix docs --warnings-as-errors
```

## Documentation Best Practices

### Writing Good Documentation

1. **Start with why**
   - Explain the purpose before the implementation
   - Provide context and use cases

2. **Include examples**
   - Show common usage patterns
   - Include both success and error cases

3. **Document edge cases**
   - Explain unusual behavior
   - Note limitations and gotchas

4. **Keep it updated**
   - Update docs with code changes
   - Remove outdated information

### Module Documentation Template

```elixir
defmodule Rachel.MyModule do
  @moduledoc """
  [One-line summary of module purpose]

  [Detailed description of what this module does and when to use it]

  ## Features

  - Feature 1
  - Feature 2
  - Feature 3

  ## Usage

      # Basic example
      MyModule.operation()

      # Advanced example
      MyModule.complex_operation(args)

  ## Notes

  - Important consideration 1
  - Important consideration 2

  See also: `RelatedModule`, `AnotherModule`
  """

  # Module implementation...
end
```

### Function Documentation Template

```elixir
@doc """
[One-line summary of what function does]

[Detailed explanation if needed]

## Parameters

  - `param1` - [Type and description]
  - `param2` - [Type and description]

## Returns

  - `{:ok, value}` - [Success case]
  - `{:error, reason}` - [Error case]

## Examples

    iex> MyModule.my_function(valid_input)
    {:ok, result}

    iex> MyModule.my_function(invalid_input)
    {:error, :invalid}

## Notes

[Any important notes, gotchas, or warnings]
"""
@spec my_function(type1(), type2()) :: {:ok, result()} | {:error, atom()}
def my_function(param1, param2) do
  # Implementation
end
```

## Troubleshooting

### Warnings During Generation

**"No documentation for function"**
- Add `@doc false` for intentionally undocumented functions
- Or add proper `@doc` documentation

**"Module X is not documented"**
- Add `@moduledoc` or `@moduledoc false`

**"Invalid link"**
- Check module names in backticks
- Ensure linked modules exist

### Missing Content

**Guides not showing**
- Check file paths in `extras` list
- Ensure files exist at specified paths

**Modules not grouped**
- Verify module names in `groups_for_modules`
- Check that modules are compiled

### Formatting Issues

**Code blocks not rendering**
- Ensure 4-space indentation
- Or use triple backticks with language

**Links broken**
- Use proper markdown link syntax
- Reference modules with backticks: `` `ModuleName` ``

## Resources

- [ExDoc Documentation](https://hexdocs.pm/ex_doc/)
- [Writing Documentation](https://hexdocs.pm/elixir/writing-documentation.html)
- [Module Attributes](https://hexdocs.pm/elixir/modules-and-functions.html#module-attributes)
- [Typespecs](https://hexdocs.pm/elixir/typespecs.html)

## Tips

### Quick Documentation Check

```bash
# Check a specific module in IEx
iex -S mix
iex> h Rachel.GameManager
iex> h Rachel.GameManager.create_game
```

### Generate Docs Automatically

Use file watching during development:

```bash
# Install fswatch (macOS)
brew install fswatch

# Watch for changes and regenerate
fswatch -o lib/**/*.ex | xargs -n1 -I{} mix docs
```

### Documentation Coverage

```bash
# Check which modules lack documentation
mix docs --warnings-as-errors
```

---

## Support

For questions about documentation:
- Check the [ExDoc guide](https://hexdocs.pm/ex_doc/)
- Review existing well-documented modules
- Ask in project discussions
