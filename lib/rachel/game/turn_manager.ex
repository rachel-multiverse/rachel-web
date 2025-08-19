defmodule Rachel.Game.TurnManager do
  @moduledoc """
  Handles turn advancement logic extracted from GameState.
  Clean, focused turn management.
  """

  @doc """
  Advances to the next active player, considering skips and direction.
  """
  def advance_turn(game) do
    # Clear suit nomination (only affects next player)
    game = %{game | nominated_suit: nil}

    next_index =
      find_next_active_player(
        game.current_player_index,
        game.players,
        game.direction,
        game.pending_skips
      )

    %{game | current_player_index: next_index, pending_skips: 0}
  end

  @doc """
  Checks if the game should end (≤1 active player).
  """
  def should_end?(game) do
    active_count = Enum.count(game.players, &(&1.status == :playing))
    active_count <= 1
  end

  @doc """
  Marks a player as winner if they emptied their hand.
  """
  def check_winner(game, player_index) do
    player = Enum.at(game.players, player_index)

    if Enum.empty?(player.hand) do
      winners = game.winners ++ [player.id]
      players = List.update_at(game.players, player_index, &Map.put(&1, :status, :won))
      %{game | winners: winners, players: players}
    else
      game
    end
  end

  # Private functions

  defp find_next_active_player(current_index, players, direction, skip_count) do
    step = if direction == :clockwise, do: 1, else: -1
    steps_to_take = 1 + skip_count
    player_count = length(players)

    next_idx = current_index + step * steps_to_take
    next_idx = Integer.mod(next_idx, player_count)

    find_active_player(next_idx, players, direction, player_count, 0)
  end

  defp find_active_player(index, players, direction, player_count, attempts) do
    if attempts >= player_count do
      # Prevent infinite loops
      index
    else
      player = Enum.at(players, index)

      if player.status == :won do
        step = if direction == :clockwise, do: 1, else: -1
        next_index = Integer.mod(index + step, player_count)
        find_active_player(next_index, players, direction, player_count, attempts + 1)
      else
        index
      end
    end
  end
end
