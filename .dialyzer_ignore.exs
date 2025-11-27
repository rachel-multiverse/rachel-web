[
  # Ignore warnings from dependencies
  {"deps/*", :unknown_function},
  {"_build/*", :unknown_function},
  # Ignore benchmarks (Benchee is dev-only dependency)
  {"lib/rachel/benchmarks/game_benchmark.ex", :unknown_function},
  # False positive - metrics/0 returns a list of metrics
  {"lib/rachel_web/telemetry.ex", :no_return},
  # Test support files reference ExUnit which is only in test env
  {"test/support/data_case.ex", :unknown_function},
  {"test/support/conn_case.ex", :unknown_function}
]
