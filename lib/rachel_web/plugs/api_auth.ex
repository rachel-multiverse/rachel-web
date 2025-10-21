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
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> {:ok, user}
      nil -> {:error, :invalid_token}
    end
  end
end