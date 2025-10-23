defmodule RachelWeb.API.AuthController do
  use RachelWeb, :controller

  alias Rachel.Accounts

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:created)
        |> json(%{
          user: user_json(user),
          token: Base.encode64(token)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      token = Accounts.generate_user_session_token(user)

      # Update user online status
      {:ok, updated_user} = Accounts.user_online(user)

      json(conn, %{
        user: user_json(updated_user),
        token: Base.encode64(token)
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid email or password"})
    end
  end

  def me(conn, _params) do
    user = conn.assigns.current_user
    json(conn, %{user: user_json(user)})
  end

  def logout(conn, _params) do
    # In a real app, you'd invalidate the token here
    user = conn.assigns.current_user
    Accounts.user_offline(user)

    json(conn, %{message: "Logged out successfully"})
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      display_name: user.display_name || user.username,
      avatar_url: user.avatar_url,
      games_played: user.games_played,
      games_won: user.games_won,
      total_turns: user.total_turns,
      is_online: user.is_online,
      preferences: user.preferences || %{}
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      translate_error_message(msg, opts)
    end)
  end

  defp translate_error_message(msg, opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      value_str = format_error_value(value)
      String.replace(acc, "%{#{key}}", value_str)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)
end
