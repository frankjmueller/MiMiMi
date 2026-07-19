defmodule MimimiWeb.Plugs.LocaleTest do
  @moduledoc """
  The UI locale (chrome language) resolves from the `ui_locale` cookie, then Accept-Language, then the
  default "de" (M3, ADR 0075). It is put in the session (so a LiveView mount can read it), assigned to the
  conn (so the root layout's <html lang> is correct) and set as the Gettext locale for this request.
  """
  use MimimiWeb.ConnCase, async: true

  alias MimimiWeb.Plugs.Locale

  defp run(conn), do: Locale.call(conn, Locale.init([]))

  test "defaults to German when nothing indicates otherwise" do
    conn = build_conn() |> Plug.Test.init_test_session(%{}) |> run()
    assert conn.assigns.ui_locale == "de"
    assert get_session(conn, "ui_locale") == "de"
  end

  test "honours the ui_locale cookie" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Map.update!(:cookies, &Map.put(&1, "ui_locale", "en"))
      |> run()

    assert conn.assigns.ui_locale == "en"
  end

  test "falls back to Accept-Language when there is no cookie" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_req_header("accept-language", "en-US,en;q=0.9,de;q=0.8")
      |> run()

    assert conn.assigns.ui_locale == "en"
  end

  test "respects Accept-Language q-values, not header order" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_req_header("accept-language", "de;q=0.1,en;q=1.0")
      |> run()

    assert conn.assigns.ui_locale == "en"
  end

  test "never selects a q=0 language" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_req_header("accept-language", "en;q=0,de;q=0.5")
      |> run()

    assert conn.assigns.ui_locale == "de"
  end

  test "ignores an unsupported locale and uses the default" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Map.update!(:cookies, &Map.put(&1, "ui_locale", "fr"))
      |> run()

    assert conn.assigns.ui_locale == "de"
  end
end
