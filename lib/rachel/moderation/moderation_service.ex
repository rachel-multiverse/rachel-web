defmodule Rachel.Moderation.ModerationService do
  @moduledoc """
  Content moderation service for user-generated text.
  Checks for profanity, URLs, spam patterns, and excessive special characters.
  """

  alias Rachel.Moderation.ModerationFlag
  alias Rachel.Repo

  # Simple profanity list - expand as needed
  @profanity_words ~w(
    damn hell shit fuck crap bastard bitch ass asshole
    dickhead piss bollocks bugger
  )

  @suspicious_patterns [
    ~r/v[i1]a?g?r?a/i,
    ~r/c[i1]al[i1]s/i,
    ~r/ch[e3]ap/i,
    ~r/f[o0]{2,}/i
  ]

  @doc """
  Checks content for violations. Returns:
  - :ok if content is clean
  - {:reject, reason} if content violates rules (immediate rejection)
  - {:flag, reason} if content is suspicious (allow but flag for review)
  """
  def check_content(text, _field_name) when is_binary(text) do
    text = String.downcase(String.trim(text))

    cond do
      contains_profanity?(text) ->
        {:reject, "contains inappropriate language"}

      contains_urls?(text) ->
        {:reject, "URLs are not allowed"}

      excessive_special_chars?(text) ->
        {:reject, "contains too many special characters"}

      suspicious_pattern?(text) ->
        {:flag, "suspicious pattern detected"}

      true ->
        :ok
    end
  end

  def check_content(nil, _field_name), do: :ok
  def check_content("", _field_name), do: :ok

  @doc """
  Creates a moderation flag for content that needs review.
  """
  def flag_for_review(user_id, field_name, content, reason) do
    %ModerationFlag{}
    |> ModerationFlag.changeset(%{
      user_id: user_id,
      field_name: Atom.to_string(field_name),
      flagged_content: content,
      reason: reason,
      status: "pending"
    })
    |> Repo.insert()
  end

  @doc """
  Lists all pending moderation flags with user information.
  """
  def list_pending_flags do
    import Ecto.Query

    ModerationFlag
    |> where([f], f.status == "pending")
    |> order_by([f], desc: f.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Counts pending moderation flags.
  """
  def count_pending_flags do
    import Ecto.Query

    ModerationFlag
    |> where([f], f.status == "pending")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts moderation flags created in the last N days.
  """
  def count_flags(opts \\ []) do
    days = Keyword.get(opts, :days, 7)
    import Ecto.Query

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    ModerationFlag
    |> where([f], f.inserted_at >= ^cutoff)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Reviews a moderation flag (approve or reject).
  """
  def review_flag(flag_id, reviewer_id, action) when action in [:approved, :rejected] do
    flag = Repo.get!(ModerationFlag, flag_id)

    flag
    |> ModerationFlag.changeset(%{
      status: Atom.to_string(action),
      reviewed_by: reviewer_id,
      reviewed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # Private helpers

  defp contains_profanity?(text) do
    Enum.any?(@profanity_words, fn word ->
      Regex.match?(~r/\b#{word}\b/i, text)
    end)
  end

  defp contains_urls?(text) do
    Regex.match?(~r/https?:\/\/|www\./i, text)
  end

  defp excessive_special_chars?(text) do
    # Count non-alphanumeric characters (excluding spaces)
    special_count = text
    |> String.replace(~r/[a-zA-Z0-9\s]/, "")
    |> String.length()

    special_count > 10
  end

  defp suspicious_pattern?(text) do
    Enum.any?(@suspicious_patterns, fn pattern ->
      Regex.match?(pattern, text)
    end)
  end
end
