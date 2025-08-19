defmodule Rachel.Game.AIPlayer do
  @moduledoc """
  AI player logic for Rachel card game.
  Different difficulties with varying strategies.
  """

  alias Rachel.Game.Rules

  @doc """
  Determines the best move for an AI player.
  Returns {:play, cards, nominated_suit} or {:draw, reason}
  """
  def choose_action(game, ai_player, difficulty \\ :medium) do
    cond do
      # Must respond to attacks
      game.pending_attack != nil ->
        handle_attack(game, ai_player, difficulty)

      # Must respond to skips
      game.pending_skips > 0 ->
        handle_skip(game, ai_player, difficulty)

      # Normal turn
      true ->
        choose_normal_action(game, ai_player, difficulty)
    end
  end

  # Handle attack situations
  defp handle_attack(game, player, difficulty) do
    {attack_type, _count} = game.pending_attack

    # Find counter cards
    counter_cards =
      Enum.filter(player.hand, fn card ->
        Rules.can_counter_attack?(card, attack_type)
      end)

    if Enum.any?(counter_cards) do
      # Choose which counter to play based on difficulty
      cards_to_play = choose_attack_counter(counter_cards, attack_type, difficulty)
      {:play, cards_to_play, nil}
    else
      {:draw, :attack}
    end
  end

  # Handle skip situations
  defp handle_skip(_game, player, _difficulty) do
    # Can only counter with 7s
    sevens = Enum.filter(player.hand, fn card -> card.rank == 7 end)

    if Enum.any?(sevens) do
      # Play all sevens to maximize skip counter
      {:play, sevens, nil}
    else
      {:draw, :cannot_play}
    end
  end

  # Choose action on normal turn
  defp choose_normal_action(game, player, difficulty) do
    top_card = hd(game.discard_pile)

    # Find all valid plays
    valid_plays = find_valid_plays(player.hand, top_card, game.nominated_suit)

    if Enum.any?(valid_plays) do
      # Choose best play based on difficulty
      {cards, nominated_suit} = choose_best_play(valid_plays, player.hand, difficulty)
      {:play, cards, nominated_suit}
    else
      {:draw, :cannot_play}
    end
  end

  # Find all possible valid plays (including stacks)
  defp find_valid_plays(hand, top_card, nominated_suit) do
    # Group cards by rank for potential stacking
    by_rank = Enum.group_by(hand, & &1.rank)

    # Find all valid single cards and stacks
    Enum.flat_map(by_rank, fn {_rank, cards} ->
      first_card = hd(cards)

      if Rules.can_play_card?(first_card, top_card, nominated_suit) do
        # Can play this rank - generate all possible stack sizes (1 to all cards of this rank)
        # Use unique cards only to prevent duplicates
        unique_cards = Enum.uniq(cards)
        generate_stack_combinations(unique_cards)
      else
        []
      end
    end)
  end

  # Generate all possible stack sizes for unique cards of the same rank
  defp generate_stack_combinations(cards) do
    1..length(cards)
    |> Enum.map(fn n ->
      Enum.take(cards, n)
    end)
  end

  # Choose best play based on difficulty
  defp choose_best_play(valid_plays, hand, :easy) do
    # Easy AI: Play randomly, don't stack much
    play = Enum.random(valid_plays)
    {play, choose_suit_nomination(play, hand, :easy)}
  end

  defp choose_best_play(valid_plays, hand, :medium) do
    # Medium AI: Prefer special cards, some stacking
    play =
      valid_plays
      |> Enum.sort_by(&play_score(&1, hand, :medium))
      # Highest score
      |> List.last()

    {play, choose_suit_nomination(play, hand, :medium)}
  end

  defp choose_best_play(valid_plays, hand, :hard) do
    # Hard AI: Optimal play, maximum stacking, save defensive cards
    play =
      valid_plays
      |> Enum.sort_by(&play_score(&1, hand, :hard))
      # Highest score
      |> List.last()

    {play, choose_suit_nomination(play, hand, :hard)}
  end

  # Score a potential play using the AIStrategy module
  defp play_score(cards, hand, difficulty) when difficulty in [:medium, :hard] do
    alias Rachel.Game.AIStrategy
    AIStrategy.score_play(cards, hand, difficulty)
  end

  # Choose suit nomination for Aces
  defp choose_suit_nomination(cards, hand, difficulty) do
    if hd(cards).rank == 14 do
      alias Rachel.Game.AIStrategy
      remaining = hand -- cards
      AIStrategy.choose_suit(remaining, difficulty)
    else
      nil
    end
  end

  # Choose which attack counter to play
  defp choose_attack_counter(counter_cards, attack_type, difficulty) do
    alias Rachel.Game.AIStrategy
    AIStrategy.choose_counter(counter_cards, attack_type, difficulty)
  end

  @doc """
  Generates a delay for AI moves to feel more natural.
  """
  def thinking_delay(difficulty) do
    base =
      case difficulty do
        :easy -> 1000
        :medium -> 1500
        :hard -> 2000
      end

    # Add some variance
    base + :rand.uniform(500)
  end

  @doc """
  Gets a personality name for the AI.
  """
  def personality_name(difficulty, index) do
    case difficulty do
      :easy ->
        ["Rookie Rachel", "Beginner Bob", "Novice Nancy", "Learner Larry"]
        |> Enum.at(index, "Easy AI")

      :medium ->
        ["Tactical Tom", "Strategic Sue", "Clever Claire", "Smart Sam"]
        |> Enum.at(index, "Medium AI")

      :hard ->
        ["Master Mike", "Expert Emma", "Champion Charlie", "Grandmaster Grace"]
        |> Enum.at(index, "Hard AI")
    end
  end
end
