[
  # Ignore warnings from dependencies
  {"deps/*", :unknown_function},
  {"_build/*", :unknown_function},
  # Ignore benchmarks (Benchee is dev-only dependency)
  {"lib/rachel/benchmarks/game_benchmark.ex", :unknown_function},
  # False positive - metrics/0 returns a list of metrics
  {"lib/rachel_web/telemetry.ex", :no_return}
]
