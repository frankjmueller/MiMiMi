defmodule MimimiWeb.InternalPagesTest do
  @moduledoc """
  M4 child-safety (ADR 0075): the /debug and /list_words pages expose internal ids and statistics, so they
  are gated behind the `:internal_pages` flag — safe-by-default OFF, so production never serves them unless
  explicitly enabled. When disabled, a visitor is redirected to the home page, never shown internals.
  """
  use MimimiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Mimimi.Accounts

  setup %{conn: conn} do
    {:ok, _user} = Accounts.get_or_create_user_by_session("internal_pages_session")
    conn = Plug.Test.init_test_session(conn, %{"session_id" => "internal_pages_session"})
    original = Application.get_env(:mimimi, :internal_pages)
    on_exit(fn -> Application.put_env(:mimimi, :internal_pages, original) end)
    %{conn: conn}
  end

  for path <- ["/debug", "/list_words"] do
    test "#{path} redirects to the home page when internal pages are disabled", %{conn: conn} do
      Application.put_env(:mimimi, :internal_pages, false)
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, unquote(path))
    end

    test "#{path} is reachable when internal pages are enabled", %{conn: conn} do
      Application.put_env(:mimimi, :internal_pages, true)
      assert {:ok, _view, _html} = live(conn, unquote(path))
    end
  end
end
