# Dependency Update Guide

This document describes how automated dependency updates work in the Rachel project and how to handle them.

## Overview

Rachel uses GitHub's Dependabot to automatically check for dependency updates and create pull requests. This ensures:
- Security vulnerabilities are addressed promptly
- Dependencies stay up-to-date with bug fixes
- Compatibility issues are caught early through CI
- Manual update overhead is minimized

## Automated Updates

### What Gets Updated

Dependabot monitors three package ecosystems:

1. **Elixir/Hex packages** (`mix.exs`)
   - Updated weekly on Mondays at 09:00 UTC
   - Groups minor and patch updates together
   - Creates separate PRs for major updates

2. **npm packages** (`assets/package.json`)
   - Updated weekly on Mondays at 09:00 UTC
   - Groups minor and patch updates together
   - Creates separate PRs for major updates

3. **GitHub Actions** (`.github/workflows/*.yml`)
   - Updated monthly on the first Monday at 09:00 UTC
   - Ensures CI workflows use latest stable actions

### Update Schedule

```
Monday 09:00 UTC:
  ├─ Elixir/Hex dependency check
  ├─ npm dependency check
  └─ Creates PRs for available updates

First Monday of Month:
  └─ GitHub Actions dependency check
```

### Grouping Strategy

**Minor and Patch Updates** (grouped):
- Security patches
- Bug fixes
- Minor feature additions
- All combined into a single PR when possible

**Major Updates** (separate):
- Breaking changes
- API changes
- Each in its own PR for careful review

## Pull Request Workflow

### 1. Dependabot Creates PR

When updates are available, Dependabot:
- Creates a pull request
- Labels it with `dependencies` and ecosystem tag
- Assigns it to configured reviewers
- Includes changelog and release notes

### 2. Automated CI Checks

The CI workflow automatically runs:

```
✓ Code formatting check (mix format)
✓ Static analysis (mix credo)
✓ Type checking (mix dialyzer)
✓ Security audit (mix sobelow, mix deps.audit)
✓ Full test suite with coverage
✓ Docker build test
```

### 3. Review Process

**For Grouped Minor/Patch Updates**:
1. Wait for CI to pass (usually 5-10 minutes)
2. Review the changelog summaries
3. Check for any deprecation warnings
4. If CI passes and no concerns → **Merge**

**For Major Updates**:
1. Wait for CI to pass
2. Review breaking changes carefully
3. Check migration guides
4. Test locally if significant changes
5. Update code to handle breaking changes
6. Merge when confident

### 4. Local Testing (Optional)

For complex updates, test locally:

```bash
# Fetch the Dependabot branch
git fetch origin
git checkout dependabot/[ecosystem]/[package]-[version]

# Update dependencies
mix deps.get

# Run tests
mix test

# Check for warnings
mix compile

# Run quality checks
mix credo
mix dialyzer

# Manual testing
iex -S mix phx.server
```

## Handling Update Failures

### CI Failures

If CI fails on a Dependabot PR:

#### Compilation Errors

```bash
# Locally check the error
mix deps.get
mix compile

# Fix code if API changed
# Update function calls, types, etc.

# Push fixes to the Dependabot branch
git commit -am "fix: Update code for new API"
git push
```

#### Test Failures

```bash
# Run failing tests
mix test

# Update tests if behavior changed
# Check if new version has different behavior

# Push fixes
git commit -am "test: Update tests for new behavior"
git push
```

#### Dialyzer Failures

```bash
# Clear PLT cache
rm -rf priv/plts
mix dialyzer --plt

# Fix type issues
mix dialyzer

# Push fixes
git commit -am "fix: Update type specs"
git push
```

### Dependency Conflicts

If dependencies conflict:

1. **Check compatibility**
   ```bash
   mix deps.tree
   ```

2. **Resolve conflicts**
   - Update mix.exs version constraints
   - Or wait for transitive dependencies to update

3. **Test resolution**
   ```bash
   mix deps.unlock --all
   mix deps.get
   mix test
   ```

### Security Vulnerabilities

If a security vulnerability is found:

1. Dependabot creates a security advisory PR immediately
2. Review the vulnerability details
3. **Prioritize merging** - security fixes should be merged ASAP
4. Deploy to production promptly

## Manual Updates

Sometimes you need to update dependencies manually:

### Update All Dependencies

```bash
# Check for outdated packages
mix hex.outdated

# Update all packages
mix deps.update --all

# Run tests
mix test

# Check everything works
mix compile
mix credo
mix dialyzer

# Commit
git add mix.lock
git commit -m "chore(deps): Update all dependencies"
```

### Update Specific Package

```bash
# Update one package
mix deps.update [package_name]

# Example
mix deps.update phoenix_live_view

# Test and commit
mix test
git add mix.lock
git commit -m "chore(deps): Update phoenix_live_view"
```

### Update npm Dependencies

```bash
cd assets

# Check outdated
npm outdated

# Update all
npm update

# Or update specific package
npm update [package]

# Test and commit
npm test  # if you have tests
cd ..
git add assets/package.lock
git commit -m "chore(deps): Update npm dependencies"
```

## Configuration

### Dependabot Configuration

Location: `.github/dependabot.yml`

**Customize update schedule**:
```yaml
schedule:
  interval: "daily"  # or "weekly", "monthly"
  day: "monday"
  time: "09:00"
  timezone: "America/New_York"
```

**Change PR limits**:
```yaml
open-pull-requests-limit: 10  # Max open PRs
```

**Add custom labels**:
```yaml
labels:
  - "dependencies"
  - "automerge"  # Custom label
```

**Ignore specific packages**:
```yaml
ignore:
  - dependency-name: "package-name"
    versions: ["1.x", "2.x"]
```

### Auto-Merge Setup (Optional)

To automatically merge minor/patch updates:

1. **Install GitHub CLI locally**
   ```bash
   brew install gh
   gh auth login
   ```

2. **Enable auto-merge for Dependabot PRs**
   ```bash
   # Create a workflow that auto-merges
   # after CI passes for minor/patch updates
   ```

3. **Or use GitHub's "Enable auto-merge" button**
   - Only for low-risk updates
   - Requires branch protection rules

## Best Practices

### Regular Maintenance

**Weekly**:
- Review and merge Dependabot PRs
- Check for security advisories
- Run `mix hex.outdated` locally

**Monthly**:
- Update major versions intentionally
- Review deprecation warnings
- Check roadmaps for packages you depend on

**Quarterly**:
- Audit all dependencies
- Remove unused dependencies
- Consider alternatives for abandoned packages

### Safe Update Strategy

1. **Always test**
   - Never merge without CI passing
   - Test major updates locally
   - Check staging environment if available

2. **Read changelogs**
   - Understand what changed
   - Look for breaking changes
   - Note deprecation warnings

3. **Update incrementally**
   - Don't update everything at once
   - Update related packages together
   - Keep PRs focused and reviewable

4. **Monitor production**
   - Watch error rates after updates
   - Check performance metrics
   - Be ready to rollback if needed

### When to Hold Updates

Don't merge if:
- CI is failing
- Breaking changes aren't understood
- You're about to deploy critical changes
- It's Friday afternoon (ship early in week)

## Troubleshooting

### Dependabot Not Creating PRs

Check:
1. `.github/dependabot.yml` syntax is valid
2. Dependabot is enabled in repo settings
3. No rate limits or GitHub issues
4. Dependencies are actually outdated

### CI Always Failing

1. Check if issue is in main branch
2. Update CI workflow if needed
3. Temporarily disable problematic checks
4. Fix main branch first, then rebase

### Merge Conflicts

```bash
# Fetch latest main
git checkout main
git pull

# Rebase Dependabot branch
git checkout dependabot/...
git rebase main

# Resolve conflicts
# Fix mix.lock, package.json.lock

# Force push
git push --force-with-lease
```

## Resources

- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Hex Package Manager](https://hex.pm/)
- [Elixir Release Notes](https://github.com/elixir-lang/elixir/releases)
- [Phoenix Release Notes](https://github.com/phoenixframework/phoenix/releases)

## Support

For questions about dependency updates:
- Check this guide first
- Review existing Dependabot PRs for patterns
- Ask in team chat or open a discussion
- Consult package documentation for major changes
