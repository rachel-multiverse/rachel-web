# Rachel Project - Prioritized Action Plan

**Generated:** 2025-10-21
**Based on:** EVALUATION_REPORT.md
**Overall Project Score:** 8.0/10 (Excellent)

---

## 🔴 CRITICAL - Do Immediately (Est: 30 minutes)

These bugs will crash production. Fix before deploying.

### 1. Fix API Authentication Bug (15 min)
**File:** `lib/rachel_web/plugs/api_auth.ex:24-27`
**Impact:** API completely broken, will crash on first request
**Priority:** CRITICAL

```elixir
# REPLACE:
defp verify_token(token) do
  case Accounts.get_user_by_session_token(token) do
    nil -> {:error, :invalid_token}
    user -> {:ok, user}  # BUG: Pattern match fails
  end
end

# WITH:
defp verify_token(token) do
  case Accounts.get_user_by_session_token(token) do
    {user, _inserted_at} -> {:ok, user}
    nil -> {:error, :invalid_token}
  end
end
```

**Verify:** Run `mix test test/rachel_web/plugs/api_auth_test.exs` (create test if missing)

---

### 2. Fix User Auth Pattern Match Bug (10 min)
**File:** `lib/rachel_web/user_auth.ex:123-149`
**Impact:** Login crashes for new/unauthenticated users
**Priority:** CRITICAL

```elixir
# REPLACE:
defp renew_session(conn, user) when conn.assigns.current_scope.user.id == user.id do
  conn
end

defp renew_session(conn, _user) do
  delete_csrf_token()
  conn
  |> configure_session(renew: true)
  |> clear_session()
end

# WITH:
defp renew_session(conn, user) do
  current_user_id = get_in(conn.assigns, [:current_scope, :user, :id])

  if current_user_id == user.id do
    conn
  else
    delete_csrf_token()
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
```

**Verify:** Test login flow end-to-end

---

### 3. Verify Fixes (5 min)
```bash
# Run full test suite
mix test

# Test auth specifically
mix test test/rachel_web/user_auth_test.exs

# Start server and verify login works
iex -S mix phx.server
```

**Checkpoint:** All tests passing, can log in successfully.

---

## 🟡 HIGH PRIORITY - Do This Week (Est: 4 hours)

Security hardening and missing tests.

### 4. Add Rate Limiting (1 hour)

**Step 1:** Add dependency
```elixir
# mix.exs
{:hammer, "~> 6.2"}
```

**Step 2:** Create plug
```bash
# Create file: lib/rachel_web/plugs/rate_limit.ex
```

Copy implementation from EVALUATION_REPORT.md section 5.3.

**Step 3:** Apply to routes
```elixir
# lib/rachel_web/router.ex
pipeline :rate_limit_strict do
  plug RachelWeb.Plugs.RateLimit, limit: 5, period_ms: 60_000, by: :ip
end

scope "/api", RachelWeb.API do
  pipe_through [:api, :rate_limit_strict]
  post "/auth/login", AuthController, :login
  post "/auth/register", AuthController, :register
end
```

**Verify:** Test that 6th request in 1 minute gets 429 error

---

### 5. Tighten CSP Headers (30 min)

**File:** `lib/rachel_web/router.ex:17-23`

Replace unsafe CSP with nonce-based approach (see EVALUATION_REPORT.md section 2.2).

**Verify:**
- LiveView still works
- No console errors about CSP violations
- Check with: https://csp-evaluator.withgoogle.com/

---

### 6. Add Security Headers (15 min)

**File:** `lib/rachel_web/endpoint.ex`

Add after `plug RachelWeb.Router`:
```elixir
plug :put_security_headers

defp put_security_headers(conn, _opts) do
  conn
  |> put_resp_header("x-frame-options", "DENY")
  |> put_resp_header("x-content-type-options", "nosniff")
  |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
  |> maybe_put_hsts_header()
end

defp maybe_put_hsts_header(conn) do
  if Application.get_env(:rachel, :env) == :prod do
    put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains; preload")
  else
    conn
  end
end
```

**Verify:** Check response headers with browser DevTools

---

### 7. Add API Integration Tests (2 hours)

**Create:** `test/rachel_web/controllers/api/game_controller_test.exs`

Test all API endpoints:
- Authentication with valid/invalid tokens
- Game creation
- Joining games
- Playing cards
- Drawing cards
- Error cases

**Goal:** 100% API coverage

---

## 🟢 MEDIUM PRIORITY - Do This Month (Est: 15 hours)

Features that improve UX and maintainability.

### 8. Link Users to Games (4 hours)
**Impact:** Proper authentication, stats tracking, prevent name spoofing

**Tasks:**
- Add `user_id` field to Player struct
- Update GameManager to accept User structs instead of names
- Update LiveView to use current_user
- Create user_games table for tracking
- Migrate existing code

**See:** EVALUATION_REPORT.md section 5 (Priority 2, part A)

---

### 9. Add Database Persistence (6 hours)
**Impact:** Resume games after restart, game history, analytics

**Tasks:**
- Create games table schema
- Add checkpoint saving to GameEngine
- Implement resume functionality
- Add game archive viewing

**See:** EVALUATION_REPORT.md section 5 (Priority 2, part B)

---

### 10. Improve Error Messages (2 hours)
**Impact:** Better UX, easier debugging

**Tasks:**
- Create GameError module with structured errors
- Update validators to use detailed errors
- Render helpful messages in LiveView
- Add error details to API responses

**See:** EVALUATION_REPORT.md section 5 (Priority 2, part C)

---

### 11. Extract LiveView Components (3 hours)
**Impact:** Better maintainability, reusability

**Tasks:**
- Create component modules for:
  - PlayerHand
  - GameBoard
  - OpponentHands
  - GameOverModal
- Refactor GameLive to use components
- Add component-level tests

**See:** EVALUATION_REPORT.md section 5 (Priority 2, part D)

---

## 🔵 PRODUCTION PREP - Before Deploying (Est: 8 hours)

Infrastructure and monitoring.

### 12. Set Up CI/CD Pipeline (2 hours)

**Create:** `.github/workflows/ci.yml`

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '28'
      - run: mix deps.get
      - run: mix test
      - run: mix credo --strict
      - run: mix sobelow --config
```

---

### 13. Production Environment Setup (2 hours)

**Tasks:**
- Generate SECRET_KEY_BASE: `mix phx.gen.secret`
- Set up DATABASE_URL on hosting platform
- Configure PHX_HOST
- Set up email provider (Mailgun/SendGrid)
- Configure SSL certificates

**Checklist:**
```bash
[ ] SECRET_KEY_BASE generated and set
[ ] DATABASE_URL configured
[ ] PHX_HOST set to production domain
[ ] Email provider API keys added
[ ] SSL certificates obtained
[ ] Force SSL enabled in production
```

---

### 14. Error Tracking & Monitoring (2 hours)

**Add Sentry:**
```elixir
# mix.exs
{:sentry, "~> 10.0"}

# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod
```

**Add Health Check:**
```elixir
# lib/rachel_web/controllers/health_controller.ex
def check(conn, _params) do
  case Ecto.Adapters.SQL.query(Rachel.Repo, "SELECT 1") do
    {:ok, _} -> json(conn, %{status: "healthy"})
    {:error, _} -> conn |> put_status(503) |> json(%{status: "unhealthy"})
  end
end
```

**Set up monitoring:**
- UptimeRobot or similar
- Monitor /health endpoint

---

### 15. Database Backup Strategy (1 hour)

**Options:**
1. **Managed database:** Use Render/Fly.io automatic backups
2. **Self-hosted:** Daily pg_dump cron job
3. **Point-in-time recovery:** Enable WAL archiving

**Recommendation:** Use managed database with automatic backups.

---

### 16. Load Testing (1 hour)

**Test with k6:**
```javascript
// load_test.js
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 100,       // 100 virtual users
  duration: '30s' // Run for 30 seconds
};

export default function() {
  let res = http.get('http://localhost:4000/');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200
  });
}
```

Run: `k6 run load_test.js`

**Target:**
- 100 concurrent users
- < 200ms response time
- No errors

---

## 📅 Timeline Summary

| Phase | Tasks | Time | When |
|-------|-------|------|------|
| **Critical Fixes** | Fix 2 bugs | 30 min | **Today** |
| **High Priority** | Security + tests | 4 hrs | This week |
| **Medium Priority** | Features | 15 hrs | This month |
| **Production Prep** | Deploy setup | 8 hrs | Before launch |

**Total estimated time:** ~27.5 hours

---

## 🎯 Recommended First Steps (Today)

1. **Fix the critical bugs** (30 min)
   - API auth tuple match
   - User auth pattern match
   - Run full test suite

2. **Add API tests** (2 hrs)
   - Create test file
   - Test all endpoints
   - Verify auth works

3. **Add rate limiting** (1 hr)
   - Install Hammer
   - Create plug
   - Apply to routes

**Total: ~3.5 hours to production-ready security**

---

## 📊 Progress Tracking

Use this checklist to track progress:

```
CRITICAL (Must Do):
[ ] Fix API auth bug
[ ] Fix user auth bug
[ ] Verify all tests pass

HIGH PRIORITY (This Week):
[ ] Add rate limiting
[ ] Tighten CSP headers
[ ] Add security headers
[ ] Add API integration tests

MEDIUM PRIORITY (This Month):
[ ] Link users to games
[ ] Add database persistence
[ ] Improve error messages
[ ] Extract LiveView components

PRODUCTION PREP (Before Launch):
[ ] Set up CI/CD
[ ] Configure production env
[ ] Add error tracking
[ ] Set up monitoring
[ ] Database backups
[ ] Load testing
```

---

## 🚀 After These Tasks

The project will be:
- ✅ Production-ready with robust security
- ✅ Properly tested (API coverage added)
- ✅ Protected from common attacks
- ✅ Maintainable with good architecture
- ✅ Ready to scale to thousands of users

---

## 📞 Need Help?

If you get stuck on any task, refer to:
1. **EVALUATION_REPORT.md** - Detailed implementation guides
2. **Phoenix docs:** https://hexdocs.pm/phoenix
3. **Elixir forum:** https://elixirforum.com

---

**Next Step:** Fix the 2 critical bugs (30 minutes) 👈 START HERE
