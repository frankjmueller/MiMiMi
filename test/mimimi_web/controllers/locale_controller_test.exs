defmodule MimimiWeb.LocaleControllerTest do
  @moduledoc """
  The UI language switch (M3, ADR 0075): sets a `ui_locale` cookie for a supported locale, ignores an
  unsupported one, and never follows an attacker-supplied absolute return_to (open-redirect guard).
  """
  use MimimiWeb.ConnCase, async: true

  test "sets the ui_locale cookie for a supported locale and redirects home", %{conn: conn} do
    conn = get(conn, ~p"/locale/en")
    assert redirected_to(conn) == "/"
    assert conn.resp_cookies["ui_locale"].value == "en"
  end

  test "ignores an unsupported locale (no cookie set)", %{conn: conn} do
    conn = get(conn, ~p"/locale/fr")
    assert redirected_to(conn) == "/"
    refute Map.has_key?(conn.resp_cookies, "ui_locale")
  end

  test "only returns to a same-site relative path", %{conn: conn} do
    conn = get(conn, ~p"/locale/en", return_to: "https://evil.example/phish")
    assert redirected_to(conn) == "/"
  end

  test "rejects a protocol-relative return_to (//host)", %{conn: conn} do
    conn = get(conn, ~p"/locale/en", return_to: "//evil.example/phish")
    assert redirected_to(conn) == "/"
  end

  test "honours a same-site relative return_to", %{conn: conn} do
    conn = get(conn, ~p"/locale/de", return_to: "/list_words")
    assert redirected_to(conn) == "/list_words"
  end
end
