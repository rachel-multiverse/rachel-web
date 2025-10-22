defmodule RachelWeb.LegalController do
  use RachelWeb, :controller

  def privacy(conn, _params) do
    render(conn, :privacy, page_title: "Privacy Policy")
  end

  def terms(conn, _params) do
    render(conn, :terms, page_title: "Terms of Service")
  end
end
