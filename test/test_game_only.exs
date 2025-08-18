ExUnit.start()

# Run only game logic tests without database
Code.require_file("test/rachel/game/card_test.exs")
Code.require_file("test/rachel/game/rules_test.exs")
