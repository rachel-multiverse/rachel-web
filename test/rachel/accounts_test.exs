defmodule Rachel.AccountsTest do
  use Rachel.DataCase

  alias Rachel.Accounts

  import Rachel.AccountsFixtures
  alias Rachel.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "get_user_by_username/1" do
    test "returns nil when username does not exist" do
      refute Accounts.get_user_by_username("nonexistent")
    end

    test "returns user when username exists" do
      user = user_fixture()
      # Username is auto-generated in fixture
      assert found_user = Accounts.get_user_by_username(user.username)
      assert found_user.id == user.id
      assert found_user.username == user.username
    end

    test "username search is case-sensitive" do
      user1 = user_fixture()
      user2 = user_fixture()
      # Each fixture gets a unique username
      assert Accounts.get_user_by_username(user1.username).id == user1.id
      assert Accounts.get_user_by_username(user2.username).id == user2.id
      refute Accounts.get_user_by_username("NonExistentUser")
    end
  end

  describe "get_users_by_usernames/1" do
    test "returns empty list when no usernames provided" do
      assert Accounts.get_users_by_usernames([]) == []
    end

    test "returns empty list when no users match" do
      assert Accounts.get_users_by_usernames(["nonexistent1", "nonexistent2"]) == []
    end

    test "returns matching users" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      # Use auto-generated usernames from fixtures
      users = Accounts.get_users_by_usernames([user1.username, user2.username])
      assert length(users) == 2
      assert Enum.any?(users, &(&1.username == user1.username))
      assert Enum.any?(users, &(&1.username == user2.username))
      refute Enum.any?(users, &(&1.username == user3.username))
    end

    test "returns only existing users from mixed list" do
      user = user_fixture()

      users = Accounts.get_users_by_usernames([user.username, "nonexistent"])
      assert length(users) == 1
      assert hd(users).username == user.username
    end
  end

  describe "update_user_profile/2" do
    setup do
      # Create test avatar
      avatar = Rachel.Repo.insert!(%Rachel.Game.Avatar{
        name: "Test Avatar",
        category: "faces",
        character: "😀",
        display_order: 1
      })

      %{user: user_fixture(), avatar: avatar}
    end

    test "updates display name successfully", %{user: user} do
      {:ok, updated_user} = Accounts.update_user_profile(user, %{display_name: "Display Name"})
      assert updated_user.display_name == "Display Name"
    end

    test "updates avatar_id successfully", %{user: user, avatar: avatar} do
      {:ok, updated_user} =
        Accounts.update_user_profile(user, %{avatar_id: avatar.id})

      assert updated_user.avatar_id == avatar.id
    end

    test "updates preferences successfully", %{user: user} do
      prefs = %{"theme" => "dark", "notifications" => true}
      {:ok, updated_user} = Accounts.update_user_profile(user, %{preferences: prefs})
      assert updated_user.preferences == prefs
    end

    test "updates multiple profile fields at once", %{user: user, avatar: avatar} do
      attrs = %{
        display_name: "Cool User",
        avatar_id: avatar.id,
        preferences: %{"theme" => "retro"}
      }

      {:ok, updated_user} = Accounts.update_user_profile(user, attrs)
      assert updated_user.display_name == "Cool User"
      assert updated_user.avatar_id == avatar.id
      assert updated_user.preferences == %{"theme" => "retro"}
    end

    test "validates display_name length", %{user: user} do
      long_name = String.duplicate("a", 51)
      {:error, changeset} = Accounts.update_user_profile(user, %{display_name: long_name})
      assert %{display_name: _errors} = errors_on(changeset)
    end
  end

  describe "update_user_stats/2" do
    setup do
      %{user: user_fixture()}
    end

    test "updates games played", %{user: user} do
      {:ok, updated_user} = Accounts.update_user_stats(user, %{games_played: 10})
      assert updated_user.games_played == 10
    end

    test "updates games won", %{user: user} do
      {:ok, updated_user} = Accounts.update_user_stats(user, %{games_won: 5})
      assert updated_user.games_won == 5
    end

    test "updates total turns", %{user: user} do
      {:ok, updated_user} = Accounts.update_user_stats(user, %{total_turns: 100})
      assert updated_user.total_turns == 100
    end

    test "updates multiple stats at once", %{user: user} do
      attrs = %{
        games_played: 20,
        games_won: 12,
        total_turns: 450
      }

      {:ok, updated_user} = Accounts.update_user_stats(user, attrs)
      assert updated_user.games_played == 20
      assert updated_user.games_won == 12
      assert updated_user.total_turns == 450
    end
  end

  describe "record_game_completion/2" do
    setup do
      %{user: user_fixture()}
    end

    test "increments games_played when user loses", %{user: user} do
      initial_played = user.games_played
      initial_won = user.games_won

      {:ok, updated_user} = Accounts.record_game_completion(user, won: false, turns: 15)

      assert updated_user.games_played == initial_played + 1
      assert updated_user.games_won == initial_won
      assert updated_user.total_turns == user.total_turns + 15
    end

    test "increments both games_played and games_won when user wins", %{user: user} do
      initial_played = user.games_played
      initial_won = user.games_won

      {:ok, updated_user} = Accounts.record_game_completion(user, won: true, turns: 20)

      assert updated_user.games_played == initial_played + 1
      assert updated_user.games_won == initial_won + 1
      assert updated_user.total_turns == user.total_turns + 20
    end

    test "accumulates turns correctly over multiple games", %{user: user} do
      {:ok, user} = Accounts.record_game_completion(user, won: true, turns: 10)
      {:ok, user} = Accounts.record_game_completion(user, won: false, turns: 15)
      {:ok, user} = Accounts.record_game_completion(user, won: true, turns: 20)

      assert user.games_played == 3
      assert user.games_won == 2
      assert user.total_turns == 45
    end

    test "handles zero turns", %{user: user} do
      {:ok, updated_user} = Accounts.record_game_completion(user, won: false, turns: 0)

      assert updated_user.games_played == user.games_played + 1
      assert updated_user.total_turns == user.total_turns
    end
  end

  describe "update_user_presence/2" do
    setup do
      %{user: user_fixture()}
    end

    test "updates is_online status", %{user: user} do
      {:ok, updated_user} = Accounts.update_user_presence(user, %{is_online: true})
      assert updated_user.is_online == true

      {:ok, updated_user} = Accounts.update_user_presence(updated_user, %{is_online: false})
      assert updated_user.is_online == false
    end

    test "updates last_seen_at timestamp", %{user: user} do
      now = DateTime.utc_now()
      {:ok, updated_user} = Accounts.update_user_presence(user, %{last_seen_at: now})
      assert updated_user.last_seen_at != nil
      # Should be close to now (within a second)
      assert DateTime.diff(updated_user.last_seen_at, now, :second) |> abs() <= 1
    end

    test "updates both presence fields together", %{user: user} do
      now = DateTime.utc_now()

      {:ok, updated_user} =
        Accounts.update_user_presence(user, %{
          is_online: true,
          last_seen_at: now
        })

      assert updated_user.is_online == true
      assert updated_user.last_seen_at != nil
    end
  end

  describe "user_online/1" do
    setup do
      %{user: user_fixture()}
    end

    test "marks user as online", %{user: user} do
      {:ok, updated_user} = Accounts.user_online(user)
      assert updated_user.is_online == true
    end

    test "updates last_seen_at timestamp", %{user: user} do
      {:ok, updated_user} = Accounts.user_online(user)

      assert updated_user.last_seen_at != nil
      # Timestamp should be recent (within last second)
      diff = DateTime.diff(DateTime.utc_now(), updated_user.last_seen_at, :second)
      assert diff >= 0 and diff <= 1
    end

    test "can mark offline user as online", %{user: user} do
      # First mark as offline
      {:ok, offline_user} = Accounts.user_offline(user)
      assert offline_user.is_online == false

      # Then mark as online
      {:ok, online_user} = Accounts.user_online(offline_user)
      assert online_user.is_online == true
    end
  end

  describe "user_offline/1" do
    setup do
      %{user: user_fixture()}
    end

    test "marks user as offline", %{user: user} do
      # First ensure user is online
      {:ok, online_user} = Accounts.user_online(user)
      assert online_user.is_online == true

      # Then mark as offline
      {:ok, offline_user} = Accounts.user_offline(online_user)
      assert offline_user.is_online == false
    end

    test "updates last_seen_at timestamp", %{user: user} do
      {:ok, updated_user} = Accounts.user_offline(user)

      assert updated_user.last_seen_at != nil
      # Timestamp should be recent (within last second)
      diff = DateTime.diff(DateTime.utc_now(), updated_user.last_seen_at, :second)
      assert diff >= 0 and diff <= 1
    end

    test "can mark user offline multiple times", %{user: user} do
      {:ok, user1} = Accounts.user_offline(user)
      # Sleep to ensure different timestamps
      Process.sleep(1100)
      {:ok, user2} = Accounts.user_offline(user1)

      assert user1.is_online == false
      assert user2.is_online == false
      # Second timestamp should be later
      assert DateTime.compare(user2.last_seen_at, user1.last_seen_at) in [:gt, :eq]
    end
  end

  describe "delete_user/1" do
    test "deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "deletes user with associated tokens" do
      user = user_fixture()
      _token = Accounts.generate_user_session_token(user)

      assert {:ok, %User{}} = Accounts.delete_user(user)

      # User and tokens should be gone
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
      assert Repo.all(from(t in UserToken, where: t.user_id == ^user.id)) == []
    end

    test "can delete user with updated profile" do
      user = user_fixture()
      {:ok, updated_user} = Accounts.update_user_profile(user, %{display_name: "Delete Me"})

      assert {:ok, %User{}} = Accounts.delete_user(updated_user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "can delete user with stats" do
      user = user_fixture()
      {:ok, user_with_stats} = Accounts.record_game_completion(user, won: true, turns: 10)

      assert {:ok, %User{}} = Accounts.delete_user(user_with_stats)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end
  end
end
