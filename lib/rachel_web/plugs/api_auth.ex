defmodule RachelWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for API authentication using Bearer tokens.
  """

  import Plug.Conn

  alias Rachel.Accounts

  def ensure_api_token(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- verify_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid or missing authorization token"})
        |> halt()
    end
  end

  defp verify_token(token) do
    # Tokens from auth endpoints are base64-encoded, need to decode
    decoded_token =
      case Base.decode64(token) do
        {:ok, decoded} -> decoded
        # If not base64, use as-is (backwards compatibility)
        :error -> token
      end

    case Accounts.get_user_by_session_token(decoded_token) do
      {user, _inserted_at} -> {:ok, user}
      nil -> {:error, :invalid_token}
    end
  end
end
