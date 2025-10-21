defmodule Rachel.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    # Game-specific fields
    field :username, :string
    field :display_name, :string
    field :avatar_url, :string
    field :games_played, :integer, default: 0
    field :games_won, :integer, default: 0
    field :total_turns, :integer, default: 0
    field :preferences, :map, default: %{}
    field :is_online, :boolean, default: false
    field :last_seen_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    # For magic link registration, we don't require password
    password_provided = Map.get(attrs, "password") || Map.get(attrs, :password)

    password_opts =
      if is_binary(password_provided) and password_provided != "" do
        opts
      else
        Keyword.put(opts, :require_password, false)
      end

    user
    |> cast(attrs, [:email, :password, :username, :display_name])
    |> validate_email(opts)
    |> validate_password(password_opts)
    |> validate_username()
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers and underscores allowed"
    )
    |> unsafe_validate_unique(:username, Rachel.Repo)
    |> unique_constraint(:username)
  end

  @doc """
  A user changeset for profile updates.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :avatar_url, :preferences])
    |> validate_length(:display_name, max: 50)
  end

  @doc """
  A user changeset for updating game statistics.
  """
  def stats_changeset(user, attrs) do
    user
    |> cast(attrs, [:games_played, :games_won, :total_turns])
    |> validate_number(:games_played, greater_than_or_equal_to: 0)
    |> validate_number(:games_won, greater_than_or_equal_to: 0)
    |> validate_number(:total_turns, greater_than_or_equal_to: 0)
  end

  @doc """
  A user changeset for updating online status.
  """
  def presence_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_online, :last_seen_at])
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Rachel.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    require_password? = Keyword.get(opts, :require_password, true)

    changeset
    |> then(fn changeset ->
      if require_password? do
        validate_required(changeset, [:password])
      else
        changeset
      end
    end)
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Rachel.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
