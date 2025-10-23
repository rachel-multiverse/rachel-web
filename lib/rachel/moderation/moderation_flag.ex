defmodule Rachel.Moderation.ModerationFlag do
  @moduledoc """
  Schema for flagged user-generated content requiring moderation review.

  Records suspicious content detected by automated filters for human review.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "moderation_flags" do
    belongs_to :user, Rachel.Accounts.User
    field :field_name, :string
    field :flagged_content, :string
    field :reason, :string
    field :status, :string, default: "pending"
    belongs_to :reviewed_by_user, Rachel.Accounts.User, foreign_key: :reviewed_by
    field :reviewed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(flag, attrs) do
    flag
    |> cast(attrs, [
      :user_id,
      :field_name,
      :flagged_content,
      :reason,
      :status,
      :reviewed_by,
      :reviewed_at
    ])
    |> validate_required([:user_id, :field_name, :flagged_content, :reason])
    |> validate_inclusion(:status, ~w(pending approved rejected))
    |> validate_inclusion(:field_name, ~w(tagline bio display_name))
  end
end
