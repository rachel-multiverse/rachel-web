defmodule Rachel.Game.PlayValidatorTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.{Card, GameError, GameState, PlayValidator}

  setup do
    players = [
      %{
        id: "p1",
        name: "Player 1",
        hand: [
          Card.new(:hearts, 5),
          Card.new(:diamonds, 5),
          Card.new(:hearts, 7),
          Card.new(:spades, 2)
        ],
        status: :playing
      },
      %{
        id: "p2",
        name: "Player 2",
        hand: [
          Card.new(:clubs, 8),
          Card.new(:hearts, 9)
        ],
        status: :playing
      }
    ]

    game = %GameState{
      players: players,
      discard_pile: [Card.new(:hearts, 8)],
      current_player_index: 0,
      status: :playing
    }

    {:ok, game: game}
  end

  describe "validate_play/3" do
    test "accepts valid play from current player", %{game: game} do
      cards = [Card.new(:hearts, 5)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects play from non-current player", %{game: game} do
      cards = [Card.new(:clubs, 8)]

      assert {:error, %GameError{type: :not_your_turn}} =
               PlayValidator.validate_play(game, "p2", cards)
    end

    test "rejects cards not in player's hand", %{game: game} do
      cards = [Card.new(:spades, 10)]

      assert {:error, %GameError{type: :cards_not_in_hand}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects duplicate cards in play", %{game: game} do
      card = Card.new(:hearts, 5)
      cards = [card, card]
      assert {:error, :duplicate_cards_in_play} = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects invalid card play", %{game: game} do
      cards = [Card.new(:spades, 2)]

      assert {:error, %GameError{type: :invalid_play}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "accepts valid stack", %{game: game} do
      cards = [Card.new(:hearts, 5), Card.new(:diamonds, 5)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects invalid stack", %{game: game} do
      cards = [Card.new(:hearts, 5), Card.new(:hearts, 7)]

      assert {:error, %GameError{type: :invalid_stack}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "validates 2s can counter 2s attack", %{game: game} do
      game = %{game | pending_attack: {:twos, 2}}
      # Player has a 2 to counter
      cards = [Card.new(:spades, 2)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects invalid counter for 2s attack", %{game: game} do
      game = %{game | pending_attack: {:twos, 2}}
      # Hearts 5 cannot counter a 2s attack - must draw
      cards = [Card.new(:hearts, 5)]

      assert {:error, %GameError{type: :invalid_counter}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "validates Black Jacks can counter Black Jack attack", %{game: game} do
      # Add Black Jack to player's hand
      players =
        List.update_at(game.players, 0, fn p ->
          %{p | hand: p.hand ++ [Card.new(:clubs, 11)]}
        end)

      game = %{game | players: players, pending_attack: {:black_jacks, 5}}

      cards = [Card.new(:clubs, 11)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "validates Red Jacks can counter Black Jack attack", %{game: game} do
      # Add Red Jack to player's hand
      players =
        List.update_at(game.players, 0, fn p ->
          %{p | hand: p.hand ++ [Card.new(:hearts, 11)]}
        end)

      game = %{game | players: players, pending_attack: {:black_jacks, 5}}

      # Red Jacks CANCEL Black Jack attacks
      cards = [Card.new(:hearts, 11)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects playing Black Jack to counter 2s attack", %{game: game} do
      # Add Black Jack to player's hand
      players =
        List.update_at(game.players, 0, fn p ->
          %{p | hand: p.hand ++ [Card.new(:clubs, 11)]}
        end)

      game = %{game | players: players, pending_attack: {:twos, 2}}

      # Cannot play Black Jack against 2s attack
      cards = [Card.new(:clubs, 11)]

      assert {:error, %GameError{type: :invalid_counter}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "validates player who has won cannot play", %{game: game} do
      players = List.update_at(game.players, 0, &Map.put(&1, :status, :won))
      game = %{game | players: players}
      cards = [Card.new(:hearts, 5)]

      assert {:error, %GameError{type: :player_already_won}} =
               PlayValidator.validate_play(game, "p1", cards)
    end

    test "validates 7s can counter pending skips", %{game: game} do
      game = %{game | pending_skips: 2}
      # Player has a 7 to counter
      cards = [Card.new(:hearts, 7)]
      assert :ok = PlayValidator.validate_play(game, "p1", cards)
    end

    test "rejects non-7s when facing pending skips", %{game: game} do
      game = %{game | pending_skips: 2}
      # Hearts 5 cannot counter skips - must play 7 or be skipped
      cards = [Card.new(:hearts, 5)]

      assert {:error, %GameError{type: :invalid_counter}} =
               PlayValidator.validate_play(game, "p1", cards)
    end
  end

  describe "validate_draw/2" do
    test "accepts draw from current player", %{game: game} do
      assert :ok = PlayValidator.validate_draw(game, "p1")
    end

    test "rejects draw from non-current player", %{game: game} do
      assert {:error, %GameError{type: :not_your_turn}} = PlayValidator.validate_draw(game, "p2")
    end

    test "rejects draw from player who has won", %{game: game} do
      players = List.update_at(game.players, 0, &Map.put(&1, :status, :won))
      game = %{game | players: players}

      assert {:error, %GameError{type: :player_already_won}} =
               PlayValidator.validate_draw(game, "p1")
    end

    test "rejects draw from non-existent player", %{game: game} do
      assert {:error, %GameError{type: :player_not_found}} =
               PlayValidator.validate_draw(game, "p99")
    end
  end
end
