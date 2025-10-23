# Performance Benchmarking & Load Testing

This directory contains performance benchmarks and load tests for the Rachel application.

## Overview

Performance testing helps us:
- **Establish baselines**: Know what "normal" performance looks like
- **Detect regressions**: Catch performance degradation before production
- **Plan capacity**: Understand system limits and scaling needs
- **Optimize**: Identify bottlenecks and optimization opportunities

## Benchmark Types

### 1. Microbenchmarks (Benchee)

Measure performance of individual operations in isolation.

**Location**: `lib/rachel/benchmarks/game_benchmark.ex`

**What it measures**:
- Game creation (2, 4, 8 players)
- Deck shuffling
- Card playing (single card, stacks)
- Card drawing
- Rule validation

**Run**:
```bash
# In IEx (recommended)
iex -S mix
iex> Rachel.Benchmarks.GameBenchmark.run()

# Or directly (may have compilation warnings)
mix run lib/rachel/benchmarks/game_benchmark.ex
```

**Output**:
- Console report with timing statistics
- HTML report at `benchmarks/results/game_benchmark.html`

**Interpreting Results**:
```
Name                          ips        average  deviation
game_creation_2_players    12.34 K       81.06 μs    ±15.2%
```

- **ips**: Iterations per second (higher is better)
- **average**: Average execution time (lower is better)
- **deviation**: Variance in measurements (lower is more consistent)

---

### 2. Load Tests (Concurrent Operations)

Measure system behavior under realistic concurrent load.

**Location**: `lib/rachel/benchmarks/load_test.ex`

**What it measures**:
- Concurrent game creation and gameplay
- System throughput (games/sec)
- Response time degradation under load
- Resource consumption patterns
- Breaking point identification

**Run**:
```bash
# In IEx (required - needs application running)
iex -S mix
iex> Rachel.Benchmarks.LoadTest.run()
```

**Test Scenarios**:
1. Light load: 10 concurrent games
2. Moderate load: 50 concurrent games
3. Heavy load: 100 concurrent games
4. Stress test: 200 concurrent games
5. Breaking point: 500 concurrent games

**Output Example**:
```
| Games | Success Rate | Throughput | Avg Time | P95 Time |
|-------|--------------|------------|----------|----------|
|    10 |       100.0% |     15.2/s |   658ms |   742ms |
|    50 |       100.0% |     45.8/s |  1092ms |  1356ms |
|   100 |        98.0% |     78.3/s |  1277ms |  1645ms |
|   200 |        92.5% |    105.7/s |  1892ms |  2458ms |
|   500 |        75.4% |    112.3/s |  4456ms |  5789ms |
```

**Breaking Point**: System fails to maintain >95% success rate

---

## Running Benchmarks

### Prerequisites

Install dependencies:
```bash
mix deps.get
```

### Quick Start

Run all benchmarks:
```bash
# Start IEx with the application
iex -S mix

# Then run benchmarks
iex> Rachel.Benchmarks.GameBenchmark.run()
iex> Rachel.Benchmarks.LoadTest.run()
```

### Advanced Options

**Run specific benchmark**:
```elixir
# In IEx
iex> Rachel.Benchmarks.GameBenchmark.run()
```

**Customize benchmark duration**:
Edit the benchmark file and adjust the `time:` parameter (in seconds):
```elixir
Benchee.run(%{...}, time: 10)  # Run for 10 seconds instead of 5
```

**Customize load test scenarios**:
Edit `lib/rachel/benchmarks/load_test.ex` and modify the `scenarios` list:
```elixir
scenarios = [
  {25, "Custom light load (25 games)"},
  {75, "Custom moderate load (75 games)"}
]
```

---

## Performance Baselines

### Microbenchmark Baselines (MBP M1, 16GB RAM)

**Expected Performance**:
- Game creation (2 players): ~10,000 ops/sec (~100μs)
- Game creation (8 players): ~5,000 ops/sec (~200μs)
- Deck shuffle: ~50,000 ops/sec (~20μs)
- Single card play: ~5,000 ops/sec (~200μs)
- Draw cards: ~3,000 ops/sec (~330μs)

**Regression Thresholds**:
- Warning: >20% slower than baseline
- Critical: >50% slower than baseline

### Load Test Baselines (MBP M1, 16GB RAM)

**Expected Performance**:
- 10 concurrent games: 100% success, ~15 games/sec
- 50 concurrent games: 100% success, ~40 games/sec
- 100 concurrent games: >98% success, ~70 games/sec
- 200 concurrent games: >95% success, ~100 games/sec

**Scaling Characteristics**:
- Linear scaling up to ~100 concurrent games
- Sub-linear scaling beyond 100 games
- Breaking point around 300-500 games (hardware dependent)

---

## Interpreting Results

### Good Performance Indicators

✅ **Consistent timings**: Low standard deviation (<20%)
✅ **Linear scaling**: Throughput increases proportionally with load
✅ **Low P95**: 95th percentile close to average (predictable performance)
✅ **High success rate**: >99% success under normal load, >95% under stress

### Performance Red Flags

❌ **High variance**: Standard deviation >30% (inconsistent performance)
❌ **Throughput plateau**: No improvement with more resources
❌ **Long tail latency**: P95 >> average (unpredictable slow requests)
❌ **Early failures**: Success rate drops below 95% at low concurrency

---

## Performance Optimization Guide

### Common Bottlenecks

1. **Database connection pool exhaustion**
   - Symptom: Failures increase at moderate load
   - Fix: Increase pool size in `config/runtime.exs`
   ```elixir
   config :rachel, Rachel.Repo,
     pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")
   ```

2. **Process spawning overhead**
   - Symptom: Slow game creation times
   - Fix: Pre-spawn process pools, optimize supervisor strategy

3. **Memory pressure**
   - Symptom: Performance degrades over time, GC pauses
   - Fix: Reduce in-memory state, implement game cleanup

4. **Ecto query N+1 problems**
   - Symptom: Database queries scale with data size
   - Fix: Add `preload` to avoid N+1 queries

### Optimization Workflow

1. **Run baseline benchmarks** to establish current performance
2. **Profile with `:fprof` or `:eprof`** to identify hot paths
3. **Make targeted optimization** to one bottleneck
4. **Re-run benchmarks** to measure improvement
5. **Commit if improved**, revert if no change or regression

### Profiling Commands

```elixir
# CPU profiling
:fprof.apply(fn -> Rachel.Game.GameState.new(["P1", "P2"]) end, [])
:fprof.profile()
:fprof.analyse()

# Memory profiling
:eprof.start()
:eprof.start_profiling([self()])
# ... run code ...
:eprof.stop_profiling()
:eprof.analyze()
```

---

## Load Testing Best Practices

### 1. Test in Isolation

Run benchmarks on dedicated hardware without other services running:
- Close browsers, IDEs, background apps
- Stop development servers (webpack, etc.)
- Disable antivirus real-time scanning

### 2. Warm Up the System

Run a light warm-up before serious benchmarks:
```bash
# Warm up Erlang VM
mix run -e "1..100 |> Enum.each(fn _ -> Rachel.Game.GameState.new([\"P1\", \"P2\"]) end)"

# Then run benchmarks
mix run lib/rachel/benchmarks/game_benchmark.ex
```

### 3. Run Multiple Times

Performance can vary due to system load, GC timing, etc.:
```bash
# Run 3 times and average results
for i in {1..3}; do
  echo "=== Run $i ==="
  mix run lib/rachel/benchmarks/load_test.ex
done
```

### 4. Monitor System Resources

Watch system resources during load tests:
```bash
# Terminal 1: Run benchmark
mix run lib/rachel/benchmarks/load_test.ex

# Terminal 2: Monitor resources
watch -n 1 'ps aux | grep beam'
watch -n 1 'free -h'
```

### 5. Test Realistic Scenarios

Load tests should simulate real user behavior:
- Mix of operations (create, play, draw, end)
- Realistic think time between actions
- Various player counts (2-8 players)
- Mix of AI and human players

---

## CI Integration

### GitHub Actions

Add benchmark job to `.github/workflows/ci.yml`:

```yaml
benchmark:
  name: Performance Benchmarks
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'

  steps:
  - uses: actions/checkout@v4

  - name: Set up Elixir
    uses: erlef/setup-beam@v1
    with:
      elixir-version: '1.18'
      otp-version: '27'

  - name: Install dependencies
    run: mix deps.get

  - name: Run benchmarks
    run: |
      mix run lib/rachel/benchmarks/game_benchmark.ex
      mix run lib/rachel/benchmarks/load_test.ex

  - name: Upload results
    uses: actions/upload-artifact@v3
    with:
      name: benchmark-results
      path: benchmarks/results/
```

**Note**: CI benchmarks are for regression detection, not absolute performance.
CI runners have variable performance, so focus on relative changes.

---

## Continuous Performance Monitoring

### Option 1: Track Baselines in Git

Store baseline results in git:
```bash
# Run and save baseline
mix run lib/rachel/benchmarks/game_benchmark.ex > benchmarks/baseline.txt
git add benchmarks/baseline.txt
git commit -m "chore: Update performance baseline"
```

Compare future runs:
```bash
mix run lib/rachel/benchmarks/game_benchmark.ex > benchmarks/current.txt
diff benchmarks/baseline.txt benchmarks/current.txt
```

### Option 2: Use Benchmark Tracking Services

- **Bencher**: https://bencher.dev (tracks benchmarks over time)
- **CodeSpeed**: https://github.com/python/codespeed (self-hosted)

---

## Troubleshooting

### Benchmark Hangs or Times Out

**Possible causes**:
- Deadlock in game logic
- Database connection pool exhausted
- Memory exhausted causing thrashing

**Debug**:
```elixir
# Add timeout to load test
Task.await_many(tasks, 30_000)  # 30 second timeout
```

### Inconsistent Results

**Possible causes**:
- Background processes consuming resources
- Thermal throttling
- Swap thrashing

**Fix**:
- Run benchmarks multiple times
- Increase benchmark duration (`time: 10` instead of `time: 5`)
- Close unnecessary applications

### OOM (Out of Memory) Errors

**Possible causes**:
- Too many concurrent games
- Memory leak in game logic
- Not enough available RAM

**Fix**:
- Reduce concurrent game count
- Monitor memory with `:observer.start()`
- Implement aggressive game cleanup

---

## Future Enhancements

Potential improvements to the benchmarking suite:

- [ ] Database query benchmarks
- [ ] LiveView connection benchmarks
- [ ] AI player decision speed benchmarks
- [ ] Binary protocol serialization benchmarks
- [ ] Automated regression detection in CI
- [ ] Benchmark history tracking
- [ ] Memory leak detection tests
- [ ] Soak testing (24+ hour runs)
- [ ] Chaos engineering scenarios

---

## Resources

- **Benchee Documentation**: https://hexdocs.pm/benchee
- **Erlang Performance Guide**: https://www.erlang.org/doc/efficiency_guide
- **Phoenix Performance Tips**: https://hexdocs.pm/phoenix/deployment.html#performance
