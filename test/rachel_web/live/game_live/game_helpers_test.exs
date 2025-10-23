defmodule RachelWeb.GameLive.GameHelpersTest do
  use ExUnit.Case, async: true

  alias RachelWeb.GameLive.GameHelpers
  alias Rachel.Game.{Card, GameState}

  setup do
    # Base game state for testing
    game = %GameState{
      id: "test-game",
      status: :playing,
      deck: [],
      discard_pile: [Card.new(:hearts, 5)],
      turn_count: 1,
      pending_attack: nil,
      pending_skips: 0,
      nominated_suit: nil,
      current_player_index: 0,
      players: [
        %{id: "player1", name: "Alice", hand: []},
        %{id: "player2", name: "Bob", hand: []}
      ]
    }

    {:ok, game: game}
  end

  describe "has_valid_plays?/2" do
    test "returns true when player has matching suit", %{game: game} do
      player = %{id: "p1", hand: [Card.new(:hearts, 10)]}
      assert GameHelpers.has_valid_plays?(game, player)
    end

    test "returns true when player has matching rank", %{game: game} do
      player = %{id: "p1", hand: [Card.new(:clubs, 5)]}
      assert GameHelpers.has_valid_plays?(game, player)
    end

    test "returns true when player has matching ace", %{game: game} do
      # Ace must match suit or rank to be playable (not wild by default)
      player = %{id: "p1", hand: [Card.new(:hearts, 14)]}
      assert GameHelpers.has_valid_plays?(game, player)
    end

    test "returns false when player has no valid plays", %{game: game} do
      player = %{id: "p1", hand: [Card.new(:clubs, 3), Card.new(:diamonds, 10)]}
      refute GameHelpers.has_valid_plays?(game, player)
    end

    test "returns false when player has empty hand", %{game: game} do
      player = %{id: "p1", hand: []}
      refute GameHelpers.has_valid_plays?(game, player)
    end

    test "checks counter ability during attack", %{game: game} do
      game_with_attack = %{game | pending_attack: {:twos, 2}}

      # 2s can counter twos attack
      player_with_two = %{id: "p1", hand: [Card.new(:hearts, 2)]}
      assert GameHelpers.has_valid_plays?(game_with_attack, player_with_two)

      # Other cards cannot
      player_with_five = %{id: "p1", hand: [Card.new(:hearts, 5)]}
      refute GameHelpers.has_valid_plays?(game_with_attack, player_with_five)
    end

    test "checks counter ability for black jack attack", %{game: game} do
      game_with_attack = %{game | pending_attack: {:black_jacks, 5}}

      # Black jacks can counter
      player_with_bj = %{id: "p1", hand: [Card.new(:clubs, 11)]}
      assert GameHelpers.has_valid_plays?(game_with_attack, player_with_bj)

      # Red jacks can counter
      player_with_rj = %{id: "p1", hand: [Card.new(:hearts, 11)]}
      assert GameHelpers.has_valid_plays?(game_with_attack, player_with_rj)

      # Other cards cannot
      player_with_two = %{id: "p1", hand: [Card.new(:hearts, 2)]}
      refute GameHelpers.has_valid_plays?(game_with_attack, player_with_two)
    end
  end

  describe "card_playable?/3" do
    test "checks standalone playability when no cards selected", %{game: game} do
      card = Card.new(:hearts, 10)
      assert GameHelpers.card_playable?(game, card, [])
    end

    test "checks stacking ability when cards already selected", %{game: game} do
      selected = [Card.new(:clubs, 5)]

      # Same rank can stack
      matching_card = Card.new(:hearts, 5)
      assert GameHelpers.card_playable?(game, matching_card, selected)

      # Different rank cannot
      different_card = Card.new(:hearts, 10)
      refute GameHelpers.card_playable?(game, different_card, selected)
    end
  end

  describe "card_playable_standalone?/2" do
    test "allows card with matching suit", %{game: game} do
      card = Card.new(:hearts, 10)
      assert GameHelpers.card_playable_standalone?(game, card)
    end

    test "allows card with matching rank", %{game: game} do
      card = Card.new(:clubs, 5)
      assert GameHelpers.card_playable_standalone?(game, card)
    end

    test "allows matching ace", %{game: game} do
      # Ace must match suit or rank (not wild by default)
      card = Card.new(:hearts, 14)
      assert GameHelpers.card_playable_standalone?(game, card)
    end

    test "rejects card with no match", %{game: game} do
      card = Card.new(:clubs, 3)
      refute GameHelpers.card_playable_standalone?(game, card)
    end

    test "during attack, only counters allowed", %{game: game} do
      game_with_attack = %{game | pending_attack: {:twos, 4}}

      # 2 can counter
      two = Card.new(:hearts, 2)
      assert GameHelpers.card_playable_standalone?(game_with_attack, two)

      # Matching suit cannot counter
      matching_suit = Card.new(:hearts, 10)
      refute GameHelpers.card_playable_standalone?(game_with_attack, matching_suit)
    end
  end

  describe "can_stack_with_selected?/2" do
    test "allows same rank to stack" do
      selected = [Card.new(:hearts, 5)]
      card = Card.new(:clubs, 5)
      assert GameHelpers.can_stack_with_selected?(card, selected)
    end

    test "rejects different rank" do
      selected = [Card.new(:hearts, 5)]
      card = Card.new(:clubs, 10)
      refute GameHelpers.can_stack_with_selected?(card, selected)
    end

    test "rejects duplicate card" do
      card = Card.new(:hearts, 5)
      selected = [card]
      refute GameHelpers.can_stack_with_selected?(card, selected)
    end

    test "works with multiple selected cards" do
      selected = [Card.new(:hearts, 5), Card.new(:clubs, 5)]
      card = Card.new(:spades, 5)
      assert GameHelpers.can_stack_with_selected?(card, selected)
    end
  end

  describe "needs_suit_nomination?/1" do
    test "returns true when list contains ace" do
      cards = [Card.new(:hearts, 14)]
      assert GameHelpers.needs_suit_nomination?(cards)
    end

    test "returns true when list contains multiple aces" do
      cards = [Card.new(:hearts, 14), Card.new(:clubs, 14)]
      assert GameHelpers.needs_suit_nomination?(cards)
    end

    test "returns true when list has ace among other cards" do
      cards = [Card.new(:hearts, 5), Card.new(:clubs, 14), Card.new(:spades, 10)]
      assert GameHelpers.needs_suit_nomination?(cards)
    end

    test "returns false when no aces present" do
      cards = [Card.new(:hearts, 5), Card.new(:clubs, 10)]
      refute GameHelpers.needs_suit_nomination?(cards)
    end

    test "returns false for empty list" do
      refute GameHelpers.needs_suit_nomination?([])
    end
  end

  describe "smart_button_text/2" do
    test "shows attack count when pending attack", %{game: game} do
      game_with_attack = %{game | pending_attack: {:twos, 4}}
      player = %{id: "p1", hand: []}

      assert GameHelpers.smart_button_text(game_with_attack, player) == "Draw 4 Cards"
    end

    test "shows optional when player has valid plays", %{game: game} do
      player = %{id: "p1", hand: [Card.new(:hearts, 10)]}

      assert GameHelpers.smart_button_text(game, player) == "Draw Card (optional)"
    end

    test "shows simple draw when no valid plays", %{game: game} do
      player = %{id: "p1", hand: [Card.new(:clubs, 3)]}

      assert GameHelpers.smart_button_text(game, player) == "Draw Card"
    end

    test "prioritizes attack over valid plays", %{game: game} do
      game_with_attack = %{game | pending_attack: {:black_jacks, 10}}
      # Has valid play normally
      player = %{id: "p1", hand: [Card.new(:hearts, 5)]}

      assert GameHelpers.smart_button_text(game_with_attack, player) == "Draw 10 Cards"
    end
  end

  describe "current_player/1" do
    test "returns player at current_player_index", %{game: game} do
      player = GameHelpers.current_player(game)
      assert player.name == "Alice"
      assert player.id == "player1"
    end

    test "returns correct player when index changes", %{game: game} do
      game = %{game | current_player_index: 1}
      player = GameHelpers.current_player(game)
      assert player.name == "Bob"
      assert player.id == "player2"
    end
  end

  describe "current_player_name/1" do
    test "returns name of current player", %{game: game} do
      assert GameHelpers.current_player_name(game) == "Alice"
    end

    test "returns correct name when player changes", %{game: game} do
      game = %{game | current_player_index: 1}
      assert GameHelpers.current_player_name(game) == "Bob"
    end
  end
end
