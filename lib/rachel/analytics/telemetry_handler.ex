defmodule Rachel.Analytics.TelemetryHandler do
  @moduledoc """
  Telemetry handler for capturing game events and recording analytics.

  Subscribes to game engine telemetry events and asynchronously records
  statistics to the analytics database without blocking game operations.
  """

  require Logger
  alias Rachel.Analytics

  @doc """
  Attaches telemetry handlers for game analytics.

  Should be called during application startup.
  """
  def attach do
    events = [
      [:rachel, :game, :created],
      [:rachel, :game, :started],
      [:rachel, :game, :finished],
      [:rachel, :game, :card_played],
      [:rachel, :game, :card_drawn],
      [:rachel, :game, :error]
    ]

    :telemetry.attach_many(
      "rachel-analytics-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Handles telemetry events and records analytics asynchronously.
  """
  def handle_event([:rachel, :game, :created], _measurements, metadata, _config) do
    # Game created - record in game_stats
    Task.start(fn ->
      try do
        player_count = metadata[:players] || 0
        ai_count = count_ai_players(metadata)

        Analytics.record_game_start(metadata.game_id, %{
          player_count: player_count,
          ai_count: ai_count,
          deck_count: metadata[:deck_count] || 1
        })
      rescue
        error ->
          Logger.warning("Failed to record game_created analytics: #{inspect(error)}")
      end
    end)
  end

  def handle_event([:rachel, :game, :started], _measurements, metadata, _config) do
    # Game started - already recorded in :created, could update status here
    Logger.debug("Game #{metadata.game_id} started with #{metadata.players} players")
  end

  def handle_event([:rachel, :game, :finished], _measurements, metadata, _config) do
    # Game finished - update game_stats with winner and completion info
    Task.start(fn ->
      try do
        winner_info = extract_winner_info(metadata)

        Analytics.record_game_finish(metadata.game_id, Map.merge(winner_info, %{
          total_turns: metadata[:total_turns] || 0
        }))
      rescue
        error ->
          Logger.warning("Failed to record game_finished analytics: #{inspect(error)}")
      end
    end)
  end

  def handle_event([:rachel, :game, :card_played], _measurements, metadata, _config) do
    # Card played - record in card_play_stats
    Task.start(fn ->
      try do
        player_info = extract_player_info(metadata)

        Analytics.record_card_play(metadata.game_id, Map.merge(player_info, %{
          turn_number: metadata[:turn_number] || 0,
          cards_played: format_cards(metadata[:cards] || []),
          was_stacked: (metadata[:stack_size] || 1) > 1,
          stack_size: metadata[:stack_size] || 1,
          nominated_suit: metadata[:nominated_suit],
          resulted_in_win: metadata[:resulted_in_win] || false
        }))
      rescue
        error ->
          Logger.warning("Failed to record card_played analytics: #{inspect(error)}")
      end
    end)
  end

  def handle_event([:rachel, :game, :card_drawn], _measurements, metadata, _config) do
    # Card drawn - record in card_draw_stats
    Task.start(fn ->
      try do
        player_info = extract_player_info(metadata)

        Analytics.record_card_draw(metadata.game_id, Map.merge(player_info, %{
          turn_number: metadata[:turn_number] || 0,
          cards_drawn: metadata[:cards_drawn] || 1,
          reason: determine_draw_reason(metadata),
          attack_type: metadata[:attack_type]
        }))
      rescue
        error ->
          Logger.warning("Failed to record card_drawn analytics: #{inspect(error)}")
      end
    end)
  end

  def handle_event([:rachel, :game, :error], _measurements, metadata, _config) do
    Logger.debug("Game #{metadata.game_id} error: #{inspect(metadata[:error_type])}")
  end

  # Helper functions

  defp count_ai_players(metadata) do
    case metadata[:player_types] do
      types when is_list(types) ->
        Enum.count(types, &(&1 == :ai))

      _ ->
        0
    end
  end

  defp extract_winner_info(metadata) do
    case metadata[:winner] do
      %{type: :ai, difficulty: diff} ->
        %{
          winner_type: "ai",
          winner_ai_difficulty: to_string(diff)
        }

      %{type: type} when type in [:human, :user] ->
        %{
          winner_type: if(metadata[:winner][:user_id], do: "user", else: "anonymous")
        }

      _ ->
        %{winner_type: "unknown"}
    end
  end

  defp extract_player_info(metadata) do
    case metadata[:player] do
      %{type: :ai, difficulty: diff} ->
        %{
          player_type: "ai",
          ai_difficulty: to_string(diff)
        }

      %{type: type, user_id: user_id} when type in [:human, :user] ->
        %{
          player_type: if(user_id, do: "user", else: "anonymous")
        }

      _ ->
        %{player_type: "unknown"}
    end
  end

  defp format_cards(cards) when is_list(cards) do
    Enum.map(cards, fn
      %{suit: suit, rank: rank} -> %{"suit" => to_string(suit), "rank" => to_string(rank)}
      card -> card
    end)
  end

  defp determine_draw_reason(metadata) do
    cond do
      metadata[:reason] == :attack_penalty -> "attack_penalty"
      metadata[:reason] == :cannot_play -> "cannot_play"
      metadata[:reason] == :voluntary -> "voluntary"
      true -> "cannot_play"
    end
  end
end
