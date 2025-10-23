defmodule Rachel.Game.GameErrorTest do
  use ExUnit.Case, async: true

  alias Rachel.Game.GameError
  alias Rachel.Game.Card

  describe "new/2 - player_not_found" do
    test "creates player not found error without details" do
      error = GameError.new(:player_not_found)

      assert error.type == :player_not_found
      assert error.message == "Player not found in this game"
      assert error.details == %{}
    end

    test "creates player not found error with details" do
      details = %{player_id: "abc123"}
      error = GameError.new(:player_not_found, details)

      assert error.type == :player_not_found
      assert error.message == "Player not found in this game"
      assert error.details == details
    end
  end

  describe "new/2 - player_already_won" do
    test "creates player already won error with player name" do
      details = %{player_name: "Alice"}
      error = GameError.new(:player_already_won, details)

      assert error.type == :player_already_won
      assert error.message == "Alice has already won and cannot play"
      assert error.details == details
    end

    test "creates player already won error without player name" do
      details = %{player_id: "p1"}
      error = GameError.new(:player_already_won, details)

      assert error.type == :player_already_won
      assert error.message == "This player has already won and cannot play"
      assert error.details == details
    end
  end

  describe "new/2 - not_your_turn" do
    test "creates not your turn error with current player name" do
      details = %{current_player: "Bob"}
      error = GameError.new(:not_your_turn, details)

      assert error.type == :not_your_turn
      assert error.message == "It's Bob's turn, please wait"
      assert error.details == details
    end

    test "creates not your turn error without current player name" do
      error = GameError.new(:not_your_turn, %{})

      assert error.type == :not_your_turn
      assert error.message == "It's not your turn yet"
    end
  end

  describe "new/2 - cards_not_in_hand" do
    test "creates cards not in hand error with card details" do
      cards = [
        Card.new(:hearts, 5),
        Card.new(:spades, 11)  # Jack = 11
      ]

      details = %{cards: cards}
      error = GameError.new(:cards_not_in_hand, details)

      assert error.type == :cards_not_in_hand
      assert error.message == "You don't have these cards: 5 of Hearts, Jack of Spades"
      assert error.details == details
    end

    test "creates cards not in hand error without card details" do
      error = GameError.new(:cards_not_in_hand, %{})

      assert error.type == :cards_not_in_hand
      assert error.message == "You don't have those cards in your hand"
    end
  end

  describe "new/2 - invalid_stack" do
    test "creates invalid stack error with cards" do
      cards = [Card.new(:hearts, 5), Card.new(:spades, 6)]
      details = %{cards: cards}
      error = GameError.new(:invalid_stack, details)

      assert error.type == :invalid_stack
      assert error.message == "You can only play multiple cards of the same rank"
      assert error.details == details
    end

    test "creates invalid stack error without cards" do
      error = GameError.new(:invalid_stack, %{})

      assert error.type == :invalid_stack
      assert error.message == "Invalid card combination"
    end
  end

  describe "new/2 - invalid_play" do
    test "creates invalid play error with nominated suit" do
      card = Card.new(:hearts, 5)
      top_card = Card.new(:spades, 7)
      details = %{card: card, top_card: top_card, nominated_suit: :clubs}

      error = GameError.new(:invalid_play, details)

      assert error.type == :invalid_play

      assert error.message ==
               "5 of Hearts doesn't match Clubs (nominated suit) or 7 of Spades"

      assert error.details == details
    end

    test "creates invalid play error without nominated suit" do
      card = Card.new(:hearts, 5)
      top_card = Card.new(:spades, 7)
      details = %{card: card, top_card: top_card}

      error = GameError.new(:invalid_play, details)

      assert error.type == :invalid_play
      assert error.message == "5 of Hearts doesn't match 7 of Spades"
      assert error.details == details
    end

    test "creates invalid play error with minimal details" do
      error = GameError.new(:invalid_play, %{})

      assert error.type == :invalid_play
      assert error.message == "That card can't be played right now"
    end
  end

  describe "new/2 - invalid_counter" do
    test "creates invalid counter error for twos attack" do
      cards = [Card.new(:hearts, 5)]
      details = %{attack_type: :twos, cards: cards}

      error = GameError.new(:invalid_counter, details)

      assert error.type == :invalid_counter
      assert error.message == "You can only counter the 2s attack with more 2s, not 5 of Hearts"
      assert error.details == details
    end

    test "creates invalid counter error for black jacks attack" do
      cards = [Card.new(:hearts, 5), Card.new(:diamonds, 3)]
      details = %{attack_type: :black_jacks, cards: cards}

      error = GameError.new(:invalid_counter, details)

      assert error.type == :invalid_counter

      assert error.message ==
               "You can only counter the Black Jack attack with more Black Jacks or Red Jacks, not 5 of Hearts, 3 of Diamonds"

      assert error.details == details
    end

    test "creates invalid counter error with minimal details" do
      error = GameError.new(:invalid_counter, %{})

      assert error.type == :invalid_counter
      assert error.message == "You can't counter this attack with those cards"
    end
  end

  describe "new/2 - game_not_found" do
    test "creates game not found error" do
      details = %{game_id: "abc123"}
      error = GameError.new(:game_not_found, details)

      assert error.type == :game_not_found
      assert error.message == "Game not found - it may have ended or been deleted"
      assert error.details == details
    end
  end

  describe "new/2 - cannot_join" do
    test "creates cannot join error when game is full" do
      details = %{reason: :game_full}
      error = GameError.new(:cannot_join, details)

      assert error.type == :cannot_join
      assert error.message == "This game is full (maximum 8 players)"
      assert error.details == details
    end

    test "creates cannot join error when game already started" do
      details = %{reason: :already_started}
      error = GameError.new(:cannot_join, details)

      assert error.type == :cannot_join
      assert error.message == "This game has already started"
      assert error.details == details
    end

    test "creates cannot join error with generic reason" do
      details = %{reason: :other}
      error = GameError.new(:cannot_join, details)

      assert error.type == :cannot_join
      assert error.message == "You can't join this game right now"
      assert error.details == details
    end
  end

  describe "new/2 - invalid_status" do
    test "creates invalid status error with current and expected status" do
      details = %{current: :waiting, expected: :playing}
      error = GameError.new(:invalid_status, details)

      assert error.type == :invalid_status
      assert error.message == "Game is waiting, expected playing"
      assert error.details == details
    end

    test "creates invalid status error without status details" do
      error = GameError.new(:invalid_status, %{})

      assert error.type == :invalid_status
      assert error.message == "Game is in the wrong state for this action"
    end
  end

  describe "new/2 - must_play" do
    test "creates must play error with playable cards list" do
      cards = [Card.new(:hearts, 5), Card.new(:diamonds, 5)]
      details = %{playable_cards: cards}

      error = GameError.new(:must_play, details)

      assert error.type == :must_play
      assert error.message == "You must play one of these cards: 5 of Hearts, 5 of Diamonds"
      assert error.details == details
    end

    test "creates must play error without card list" do
      error = GameError.new(:must_play, %{})

      assert error.type == :must_play
      assert error.message == "You have cards you can play - you must play before drawing"
    end

    test "creates must play error with empty playable cards" do
      details = %{playable_cards: []}
      error = GameError.new(:must_play, details)

      assert error.type == :must_play
      assert error.message == "You have cards you can play - you must play before drawing"
    end
  end

  describe "new/2 - must_draw" do
    test "creates must draw error for twos attack" do
      details = %{pending_attack: {:twos, 4}}
      error = GameError.new(:must_draw, details)

      assert error.type == :must_draw
      assert error.message == "You must draw 4 cards from the 2s attack or counter it"
      assert error.details == details
    end

    test "creates must draw error for black jacks attack" do
      details = %{pending_attack: {:black_jacks, 10}}
      error = GameError.new(:must_draw, details)

      assert error.type == :must_draw

      assert error.message ==
               "You must draw 10 cards from the Black Jacks attack or counter it"

      assert error.details == details
    end

    test "creates must draw error for unknown attack type" do
      details = %{pending_attack: {:unknown, 5}}
      error = GameError.new(:must_draw, details)

      assert error.type == :must_draw
      assert error.message == "You must draw 5 cards from the attack attack or counter it"
    end

    test "creates must draw error without attack details" do
      error = GameError.new(:must_draw, %{})

      assert error.type == :must_draw
      assert error.message == "You must draw cards from the attack"
    end
  end

  describe "card and suit name formatting" do
    test "formats numbered cards correctly" do
      cards = [
        Card.new(:hearts, 2),
        Card.new(:diamonds, 5),
        Card.new(:clubs, 10)
      ]

      details = %{cards: cards}
      error = GameError.new(:cards_not_in_hand, details)

      assert error.message == "You don't have these cards: 2 of Hearts, 5 of Diamonds, 10 of Clubs"
    end

    test "formats face cards correctly" do
      cards = [
        Card.new(:hearts, 14),  # Ace = 14
        Card.new(:diamonds, 13),  # King = 13
        Card.new(:clubs, 12),  # Queen = 12
        Card.new(:spades, 11)  # Jack = 11
      ]

      details = %{cards: cards}
      error = GameError.new(:cards_not_in_hand, details)

      assert error.message ==
               "You don't have these cards: Ace of Hearts, King of Diamonds, Queen of Clubs, Jack of Spades"
    end

    test "formats all suit names correctly" do
      card = Card.new(:hearts, 5)
      top_card = Card.new(:spades, 7)

      for suit <- [:hearts, :diamonds, :clubs, :spades] do
        details = %{card: card, top_card: top_card, nominated_suit: suit}
        error = GameError.new(:invalid_play, details)

        suit_name = suit |> Atom.to_string() |> String.capitalize()
        assert error.message =~ suit_name
      end
    end
  end

  describe "to_string/1" do
    test "converts error to string message" do
      error = GameError.new(:player_not_found, %{player_id: "abc"})

      assert GameError.to_string(error) == "Player not found in this game"
    end

    test "converts error with formatted cards to string" do
      cards = [Card.new(:hearts, 14), Card.new(:spades, 13)]  # Ace = 14, King = 13
      error = GameError.new(:cards_not_in_hand, %{cards: cards})

      assert GameError.to_string(error) ==
               "You don't have these cards: Ace of Hearts, King of Spades"
    end
  end

  describe "to_map/1" do
    test "converts error to map for JSON response" do
      details = %{player_id: "abc123"}
      error = GameError.new(:player_not_found, details)

      map = GameError.to_map(error)

      assert map.error == :player_not_found
      assert map.message == "Player not found in this game"
      assert map.details == details
    end

    test "converts error with nil details to map" do
      error = %GameError{
        type: :game_not_found,
        message: "Game not found",
        details: nil
      }

      map = GameError.to_map(error)

      assert map.error == :game_not_found
      assert map.message == "Game not found"
      assert map.details == nil
    end

    test "converts error with complex details to map" do
      cards = [Card.new(:hearts, 5)]

      error =
        GameError.new(:cards_not_in_hand, %{
          cards: cards,
          player_id: "p1",
          attempt: 1
        })

      map = GameError.to_map(error)

      assert map.error == :cards_not_in_hand
      assert map.message == "You don't have these cards: 5 of Hearts"
      assert map.details.cards == cards
      assert map.details.player_id == "p1"
      assert map.details.attempt == 1
    end
  end

  describe "error struct" do
    test "can create error struct directly" do
      error = %GameError{
        type: :custom_error,
        message: "Custom message",
        details: %{key: "value"}
      }

      assert error.type == :custom_error
      assert error.message == "Custom message"
      assert error.details == %{key: "value"}
    end

    test "error struct has correct fields" do
      error = GameError.new(:player_not_found)

      assert Map.has_key?(error, :type)
      assert Map.has_key?(error, :message)
      assert Map.has_key?(error, :details)
    end
  end
end
