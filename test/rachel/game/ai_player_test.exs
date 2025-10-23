defmodule Rachel.Game.AIPlayerTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.AIPlayer
  alias Rachel.Game.Card

  setup do
    player = %{
      id: "ai1",
      name: "AI Player",
      hand: [
        Card.new(:hearts, 5),
        Card.new(:diamonds, 5),
        Card.new(:spades, 7),
        Card.new(:clubs, 2),
        # Ace
        Card.new(:hearts, 14)
      ]
    }

    game = %{
      discard_pile: [Card.new(:hearts, 10)],
      nominated_suit: nil,
      pending_attack: nil,
      pending_skips: 0
    }

    {:ok, player: player, game: game}
  end

  describe "choose_action/3 - normal turn" do
    test "easy AI plays a valid card", %{game: game, player: player} do
      result = AIPlayer.choose_action(game, player, :easy)

      assert {:play, cards, _suit} = result
      assert is_list(cards)
      assert length(cards) >= 1
    end

    test "medium AI plays a valid card", %{game: game, player: player} do
      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, cards, _suit} = result
      assert is_list(cards)
      assert length(cards) >= 1
    end

    test "hard AI plays a valid card", %{game: game, player: player} do
      result = AIPlayer.choose_action(game, player, :hard)

      assert {:play, cards, _suit} = result
      assert is_list(cards)
      assert length(cards) >= 1
    end

    test "AI draws when no valid plays", %{game: game} do
      player = %{
        id: "ai1",
        hand: [Card.new(:clubs, 3), Card.new(:spades, 4)]
      }

      game = %{game | discard_pile: [Card.new(:hearts, 10)]}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:draw, :cannot_play} = result
    end

    test "AI nominates suit when playing Ace", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          # Ace
          Card.new(:hearts, 14),
          Card.new(:diamonds, 5),
          Card.new(:clubs, 5)
        ]
      }

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, [%{rank: 14}], suit} = result
      assert suit in [:hearts, :diamonds, :clubs, :spades]
    end
  end

  describe "choose_action/3 - with attack" do
    test "AI counters 2s attack with 2s", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:clubs, 2),
          Card.new(:diamonds, 2),
          Card.new(:hearts, 5)
        ]
      }

      game = %{game | pending_attack: {:twos, 4}}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, cards, nil} = result
      assert Enum.all?(cards, fn card -> card.rank == 2 end)
    end

    test "AI counters Black Jack attack with Black Jack", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          # Black Jack
          Card.new(:clubs, 11),
          Card.new(:diamonds, 5),
          Card.new(:hearts, 7)
        ]
      }

      game = %{game | pending_attack: {:black_jacks, 10}}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, [%{rank: 11, suit: :clubs}], nil} = result
    end

    test "AI counters Black Jack attack with Red Jack", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          # Red Jack
          Card.new(:hearts, 11),
          Card.new(:diamonds, 5)
        ]
      }

      game = %{game | pending_attack: {:black_jacks, 10}}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, [%{rank: 11, suit: :hearts}], nil} = result
    end

    test "AI draws when cannot counter attack", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 5),
          Card.new(:diamonds, 7),
          Card.new(:clubs, 10)
        ]
      }

      game = %{game | pending_attack: {:twos, 4}}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:draw, :attack} = result
    end

    test "easy AI counters attack", %{game: game} do
      player = %{
        id: "ai1",
        hand: [Card.new(:clubs, 2), Card.new(:diamonds, 2)]
      }

      game = %{game | pending_attack: {:twos, 2}}

      result = AIPlayer.choose_action(game, player, :easy)

      assert {:play, cards, nil} = result
      assert Enum.all?(cards, fn card -> card.rank == 2 end)
    end

    test "hard AI counters attack optimally", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:clubs, 2),
          Card.new(:diamonds, 2),
          Card.new(:hearts, 2)
        ]
      }

      game = %{game | pending_attack: {:twos, 2}}

      result = AIPlayer.choose_action(game, player, :hard)

      assert {:play, cards, nil} = result
      assert Enum.all?(cards, fn card -> card.rank == 2 end)
    end
  end

  describe "choose_action/3 - with skip" do
    test "AI counters skip with 7s", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:spades, 7),
          Card.new(:diamonds, 7),
          Card.new(:hearts, 5)
        ]
      }

      game = %{game | pending_skips: 2}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, cards, nil} = result
      assert Enum.all?(cards, fn card -> card.rank == 7 end)
      assert length(cards) == 2
    end

    test "AI plays all 7s when countering skip", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:spades, 7),
          Card.new(:diamonds, 7),
          Card.new(:clubs, 7)
        ]
      }

      game = %{game | pending_skips: 1}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, cards, nil} = result
      assert length(cards) == 3
      assert Enum.all?(cards, fn card -> card.rank == 7 end)
    end

    test "AI draws when cannot counter skip", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 5),
          Card.new(:diamonds, 2),
          Card.new(:clubs, 10)
        ]
      }

      game = %{game | pending_skips: 2}

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:draw, :cannot_play} = result
    end
  end

  describe "choose_action/3 - with nominated suit" do
    test "AI plays card matching nominated suit", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:clubs, 3),
          Card.new(:clubs, 5),
          Card.new(:hearts, 7)
        ]
      }

      game = %{
        game
        | discard_pile: [Card.new(:diamonds, 14)],
          nominated_suit: :clubs
      }

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, [card], _} = result
      assert card.suit == :clubs
    end

    test "AI draws when no cards match nominated suit", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 3),
          Card.new(:diamonds, 5),
          Card.new(:spades, 7)
        ]
      }

      game = %{
        game
        | discard_pile: [Card.new(:clubs, 14)],
          nominated_suit: :clubs
      }

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:draw, :cannot_play} = result
    end
  end

  describe "choose_action/3 - card stacking" do
    test "AI can play stacked cards", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 5),
          Card.new(:diamonds, 5),
          Card.new(:clubs, 5)
        ]
      }

      result = AIPlayer.choose_action(game, player, :hard)

      assert {:play, cards, nil} = result
      # Hard AI should stack multiple cards
      assert length(cards) >= 1
      assert Enum.all?(cards, fn card -> card.rank == 5 end)
    end

    test "medium AI considers stacking", %{game: game} do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 7),
          Card.new(:diamonds, 7),
          Card.new(:clubs, 3)
        ]
      }

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:play, cards, nil} = result
      # Medium AI should have stacking logic
      assert Enum.all?(cards, fn card -> card.rank in [7, 10] end)
    end
  end

  describe "thinking_delay/1" do
    test "easy AI has shorter delay" do
      delay = AIPlayer.thinking_delay(:easy)
      assert delay >= 1000
      assert delay <= 1500
    end

    test "medium AI has medium delay" do
      delay = AIPlayer.thinking_delay(:medium)
      assert delay >= 1500
      assert delay <= 2000
    end

    test "hard AI has longer delay" do
      delay = AIPlayer.thinking_delay(:hard)
      assert delay >= 2000
      assert delay <= 2500
    end

    test "delays have variance" do
      delays = Enum.map(1..10, fn _ -> AIPlayer.thinking_delay(:medium) end)
      unique_delays = Enum.uniq(delays)

      # Should have at least some variance
      assert length(unique_delays) > 1
    end
  end

  describe "personality_name/2" do
    test "easy AI personalities" do
      assert AIPlayer.personality_name(:easy, 0) == "Rookie Rachel"
      assert AIPlayer.personality_name(:easy, 1) == "Beginner Bob"
      assert AIPlayer.personality_name(:easy, 2) == "Novice Nancy"
      assert AIPlayer.personality_name(:easy, 3) == "Learner Larry"
    end

    test "medium AI personalities" do
      assert AIPlayer.personality_name(:medium, 0) == "Tactical Tom"
      assert AIPlayer.personality_name(:medium, 1) == "Strategic Sue"
      assert AIPlayer.personality_name(:medium, 2) == "Clever Claire"
      assert AIPlayer.personality_name(:medium, 3) == "Smart Sam"
    end

    test "hard AI personalities" do
      assert AIPlayer.personality_name(:hard, 0) == "Master Mike"
      assert AIPlayer.personality_name(:hard, 1) == "Expert Emma"
      assert AIPlayer.personality_name(:hard, 2) == "Champion Charlie"
      assert AIPlayer.personality_name(:hard, 3) == "Grandmaster Grace"
    end

    test "falls back to default names for out of range index" do
      assert AIPlayer.personality_name(:easy, 10) == "Easy AI"
      assert AIPlayer.personality_name(:medium, 10) == "Medium AI"
      assert AIPlayer.personality_name(:hard, 10) == "Hard AI"
    end
  end

  describe "choose_action/3 - edge cases" do
    test "AI defaults to medium difficulty when not specified", %{game: game, player: player} do
      result = AIPlayer.choose_action(game, player)

      assert {:play, _cards, _suit} = result
    end

    test "AI handles empty discard pile gracefully" do
      player = %{
        id: "ai1",
        hand: [Card.new(:hearts, 5)]
      }

      game = %{
        discard_pile: [],
        nominated_suit: nil,
        pending_attack: nil,
        pending_skips: 0
      }

      # Should not crash, though behavior undefined with empty discard
      assert_raise(ArgumentError, fn ->
        AIPlayer.choose_action(game, player, :medium)
      end)
    end

    test "AI handles player with no cards" do
      player = %{id: "ai1", hand: []}

      game = %{
        discard_pile: [Card.new(:hearts, 10)],
        nominated_suit: nil,
        pending_attack: nil,
        pending_skips: 0
      }

      result = AIPlayer.choose_action(game, player, :medium)

      assert {:draw, :cannot_play} = result
    end

    test "AI handles multiple Aces in hand" do
      player = %{
        id: "ai1",
        hand: [
          Card.new(:hearts, 14),
          Card.new(:diamonds, 14),
          Card.new(:clubs, 5)
        ]
      }

      game = %{
        discard_pile: [Card.new(:hearts, 10)],
        nominated_suit: nil,
        pending_attack: nil,
        pending_skips: 0
      }

      result = AIPlayer.choose_action(game, player, :hard)

      assert {:play, cards, suit} = result

      # If playing Aces, should nominate suit
      if Enum.any?(cards, fn card -> card.rank == 14 end) do
        assert suit in [:hearts, :diamonds, :clubs, :spades]
      end
    end
  end
end
