defmodule MimimiWeb.LocaleController do
  @moduledoc """
  Sets the UI language cookie (M3, ADR 0075). The footer's language switcher links here; we store a
  long-lived `ui_locale` cookie (only for a supported locale) and redirect back to where the visitor was.
  The game's content language is unaffected — this is the chrome language only.
  """
  use MimimiWeb, :controller

  def update(conn, %{"locale" => locale} = params) do
    conn =
      if locale in MimimiWeb.Plugs.Locale.supported() do
        put_resp_cookie(conn, "ui_locale", locale, max_age: 60 * 60 * 24 * 365, http_only: false)
      else
        conn
      end

    redirect(conn, to: safe_return_to(params["return_to"]))
  end

  # Only same-site relative paths are honoured — never an attacker-supplied absolute URL (open redirect).
  defp safe_return_to("/" <> _ = path), do: path
  defp safe_return_to(_), do: "/"
end
