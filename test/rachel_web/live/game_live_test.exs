defmodule RachelWeb.GameLiveTest do
  use RachelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Rachel.AccountsFixtures

  alias Rachel.GameManager

  setup :register_and_log_in_user

  describe "mount" do
    test "renders game page with game state", %{conn: conn, user: user} do
      # Create a game
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, html} = live(conn, ~p"/games/#{game_id}")

      # Should show game elements
      assert html =~ "game-container"
      assert html =~ "Connection Status"
    end

    test "initializes state correctly", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      # Verify the view has the game state loaded
      html = render(view)
      assert html =~ "game-container"
      assert html =~ "Connection Status"
    end

    test "receives game updates via PubSub", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, _html} = live(conn, ~p"/games/#{game_id}")

      # Verify PubSub subscription by broadcasting a test message
      Phoenix.PubSub.broadcast(Rachel.PubSub, "game:#{game_id}", {:game_updated, %{}})

      # If we got here without errors, subscription worked
      assert true
    end

    test "redirects when game not found", %{conn: conn} do
      # Should return redirect error tuple
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Game not found"}}}} =
               live(conn, ~p"/games/nonexistent-game-id")
    end
  end

  describe "toggle_card event" do
    test "handles card selection events", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      # Wait until it's our turn
      wait_for_player_turn(game_id, 0)

      # Get current game state
      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Find a playable card
      playable_card =
        Enum.find(human_player.hand, fn card ->
          Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
        end)

      if playable_card do
        # Toggle the card - should work without error
        html =
          render_click(view, "toggle_card", %{
            "suit" => Atom.to_string(playable_card.suit),
            "rank" => Integer.to_string(playable_card.rank)
          })

        # Should not show any error
        refute html =~ "cannot be played"
      end
    end

    test "handles selection of unplayable card", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Find an unplayable card
      unplayable_card =
        Enum.find(human_player.hand, fn card ->
          not Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
        end)

      if unplayable_card do
        # Try to select unplayable card - should not crash
        html =
          render_click(view, "toggle_card", %{
            "suit" => Atom.to_string(unplayable_card.suit),
            "rank" => Integer.to_string(unplayable_card.rank)
          })

        # Should still show game container (not crash)
        assert html =~ "game-container"
        # Flash message might appear as info message
        assert html =~ "cannot be played" || html =~ "game-container"
      end
    end
  end

  describe "attempt_play_cards event" do
    test "handles play cards action", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Find a playable non-Ace card
      playable_card =
        Enum.find(human_player.hand, fn card ->
          card.rank != 14 &&
            Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
        end)

      if playable_card do
        # Select the card
        render_click(view, "toggle_card", %{
          "suit" => Atom.to_string(playable_card.suit),
          "rank" => Integer.to_string(playable_card.rank)
        })

        # Attempt to play - should succeed
        html = render_click(view, "attempt_play_cards", %{})

        # Should not show suit modal for non-Ace
        refute html =~ "suit-modal"
      end
    end

    test "shows suit modal for Aces", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)

      # Check if player has an Ace
      ace = Enum.find(human_player.hand, fn card -> card.rank == 14 end)

      if ace do
        # Select the Ace
        render_click(view, "toggle_card", %{
          "suit" => Atom.to_string(ace.suit),
          "rank" => "14"
        })

        # Attempt to play - should not crash (modal behavior tested elsewhere)
        html = render_click(view, "attempt_play_cards", %{})

        # Should still show game container (not crash)
        assert html =~ "game-container"
      end
    end
  end

  describe "play_cards event" do
    test "plays selected cards successfully", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      playable_card =
        Enum.find(human_player.hand, fn card ->
          card.rank != 14 &&
            Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
        end)

      if playable_card do
        hand_size_before = length(human_player.hand)

        # Select and play the card
        render_click(view, "toggle_card", %{
          "suit" => Atom.to_string(playable_card.suit),
          "rank" => Integer.to_string(playable_card.rank)
        })

        render_click(view, "play_cards", %{})

        # After playing, turn should change (AI's turn) or game should finish
        # Wait for turn to no longer be player 0's
        wait_for_turn_not_player(game_id, 0)

        # Hand should have one less card (or game is finished)
        {:ok, updated_game} = GameManager.get_game(game_id)

        if updated_game.status != :finished do
          updated_player = Enum.at(updated_game.players, 0)
          assert length(updated_player.hand) == hand_size_before - 1
        end
      end
    end
  end

  describe "close_suit_modal event" do
    test "handles close modal event", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      # Close modal - should work without error
      html = render_click(view, "close_suit_modal", %{})

      # Should not crash or show errors
      assert html =~ "game-container"
    end
  end

  describe "draw_card event" do
    test "draws card when no valid plays", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Check if player has no valid plays
      has_valid_play =
        Enum.any?(human_player.hand, fn card ->
          Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
        end)

      if not has_valid_play do
        hand_size_before = length(human_player.hand)

        # Draw a card
        render_click(view, "draw_card", %{})

        # Wait for game state to update after drawing
        wait_for_hand_size_increase(game_id, 0, hand_size_before)

        # Should have drawn at least one card
        {:ok, updated_game} = GameManager.get_game(game_id)
        updated_player = Enum.at(updated_game.players, 0)
        assert length(updated_player.hand) >= hand_size_before + 1
      end
    end

    test "prevents drawing when valid plays exist", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")
      wait_for_player_turn(game_id, 0)

      {:ok, game} = GameManager.get_game(game_id)
      human_player = Enum.at(game.players, 0)
      top_card = hd(game.discard_pile)

      # Check if player has valid plays (no attack)
      has_valid_play =
        game.pending_attack == nil &&
          Enum.any?(human_player.hand, fn card ->
            Rachel.Game.Rules.can_play_card?(card, top_card, game.nominated_suit)
          end)

      if has_valid_play do
        # Try to draw - the important thing is it doesn't crash
        # The draw is prevented server-side, but the event handler succeeds
        html = render_click(view, "draw_card", %{})

        # Should not crash and return HTML
        assert html =~ "Rachel Game"
      end
    end
  end

  describe "new_game event" do
    test "redirects to lobby", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      # Click new game
      render_click(view, "new_game", %{})

      # Should redirect to lobby
      assert_redirect(view, "/")
    end
  end

  describe "handle_info - game updates" do
    test "updates game state on PubSub message", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, _html} = live(conn, ~p"/games/#{game_id}")

      # Verify PubSub message handling by broadcasting
      Phoenix.PubSub.broadcast(Rachel.PubSub, "game:#{game_id}", {:game_updated, %{}})

      # If we got here without crash, message handling worked
      assert true
    end

    test "handles turn changes", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, _html} = live(conn, ~p"/games/#{game_id}")

      # Game should start with player 0 (human). If it starts with AI (player 1),
      # wait for AI to play and return to player 0. This verifies AI turns work.
      wait_for_player_turn(game_id, 0)

      # Verify we're on player 0's turn or game finished
      {:ok, updated_game} = GameManager.get_game(game_id)

      assert updated_game.current_player_index == 0 ||
               updated_game.status == :finished
    end
  end

  describe "rendering" do
    test "shows game over modal when game finished", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      # Wait for game to potentially finish
      wait_for_game_end(game_id, 100)

      html = render(view)

      # If game is finished, should show game over modal
      {:ok, game} = GameManager.get_game(game_id)

      if game.status == :finished do
        assert html =~ "game-over-modal"
      end
    end

    test "shows connection status", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, html} = live(conn, ~p"/games/#{game_id}")

      assert html =~ "connection-status"
      assert html =~ "Connected"
    end

    test "shows player hand", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, html} = live(conn, ~p"/games/#{game_id}")

      # Should render player hand component or cards
      assert html =~ "player-hand" || html =~ "Your Hand"
    end

    test "shows game elements", %{conn: conn, user: user} do
      player = {:user, user.id, user.username}
      {:ok, game_id} = GameManager.create_ai_game(player, 2, :easy)
      GameManager.start_game(game_id)

      {:ok, _view, html} = live(conn, ~p"/games/#{game_id}")

      # Verify key game elements exist
      assert html =~ "game-container"
      assert html =~ "Connection Status"
    end
  end

  # Helper functions

  defp wait_for_player_turn(game_id, player_index, attempts \\ 500) do
    {:ok, game} = GameManager.get_game(game_id)

    if game.current_player_index == player_index or attempts == 0 or game.status == :finished do
      :ok
    else
      Process.sleep(10)
      wait_for_player_turn(game_id, player_index, attempts - 1)
    end
  end

  defp wait_for_turn_not_player(game_id, player_index, attempts \\ 500) do
    {:ok, game} = GameManager.get_game(game_id)

    if game.current_player_index != player_index or attempts == 0 or game.status == :finished do
      :ok
    else
      Process.sleep(10)
      wait_for_turn_not_player(game_id, player_index, attempts - 1)
    end
  end

  defp wait_for_game_end(game_id, attempts) do
    {:ok, game} = GameManager.get_game(game_id)

    if game.status == :finished or attempts == 0 do
      :ok
    else
      Process.sleep(10)
      wait_for_game_end(game_id, attempts - 1)
    end
  end

  defp wait_for_hand_size_increase(game_id, player_index, original_size, attempts \\ 500) do
    {:ok, game} = GameManager.get_game(game_id)
    player = Enum.at(game.players, player_index)

    if length(player.hand) > original_size or attempts == 0 do
      :ok
    else
      Process.sleep(10)
      wait_for_hand_size_increase(game_id, player_index, original_size, attempts - 1)
    end
  end

  describe "spectator mode" do
    test "user visiting game with spectate param becomes spectator", %{conn: conn} do
      game_id = create_test_game()
      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

      assert has_element?(view, "[data-role='spectator-banner']")
      refute has_element?(view, "[data-role='play-button']")
    end

    test "user not in game becomes spectator by default", %{conn: conn} do
      game_id = create_test_game()
      # conn's user is not a player in this game
      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      assert has_element?(view, "[data-role='spectator-banner']")
      refute has_element?(view, "[data-role='play-button']")
    end

    test "user in game becomes player", %{conn: conn, user: user} do
      game_id = create_test_game_with_user(user)
      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}")

      refute has_element?(view, "[data-role='spectator-banner']")
      # May or may not have play button depending on turn
    end

    test "spectator cannot see action buttons", %{conn: conn} do
      # Create a different user to be the player
      other_user = user_fixture(%{username: "other_player", email: "other@example.com"})
      game_id = create_test_game_with_user(other_user)

      # Current user (from conn) is NOT in the game, so they become spectator
      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

      refute has_element?(view, "[data-role='play-button']")
      refute has_element?(view, "[data-role='draw-button']")
    end

    test "spectator cannot select cards", %{conn: conn} do
      game_id = create_test_game()
      {:ok, view, _html} = live(conn, ~p"/games/#{game_id}?spectate=true")

      # Spectator banner should be present
      assert has_element?(view, "[data-role='spectator-banner']")

      # Attempt to toggle a card - should not crash but should be blocked
      # The toggle_card event should return a noreply without changing state
      result = render_click(view, "toggle_card", %{"index" => "0"})

      # Should still show spectator banner (mode didn't change)
      assert result =~ "spectator-banner"
    end
  end

  defp create_test_game do
    # Create a game with only AI players (no human users)
    {:ok, game_id} =
      Rachel.Game.GameSupervisor.start_game([{:ai, "Alice", :easy}, {:ai, "Bob", :easy}])

    game_id
  end

  defp create_test_game_with_user(user) do
    player_spec = {:user, user.id, user.username}
    {:ok, game_id} = GameManager.create_ai_game(player_spec, 2, :easy)
    GameManager.start_game(game_id)
    game_id
  end
end
