defmodule MimimiWeb.I18nTest do
  @moduledoc """
  End-to-end UI translation (M3, ADR 0075): the home page renders German by default and English when the
  `ui_locale` cookie is "en". This proves the whole chain — Locale plug → session → LocaleHook (LiveView
  mount) → gettext with the en translation — works. The game's content language is separate (M2).
  """
  use MimimiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mimimi.Accounts

  setup %{conn: conn} do
    {:ok, _user} = Accounts.get_or_create_user_by_session("i18n_session")
    conn = Plug.Test.init_test_session(conn, %{"session_id" => "i18n_session"})
    %{conn: conn}
  end

  test "the home page is German by default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Neues Spiel"
    assert html =~ ~s(lang="de")
  end

  test "the home page renders English when the ui_locale cookie is en" do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.put_req_cookie("ui_locale", "en")
      |> Plug.Test.init_test_session(%{"session_id" => "i18n_session"})

    {:ok, _view, html} = live(conn, "/")
    assert html =~ "New game"
    refute html =~ "Neues Spiel"
    assert html =~ ~s(lang="en")
  end
end
