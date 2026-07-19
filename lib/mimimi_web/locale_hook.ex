defmodule MimimiWeb.LocaleHook do
  @moduledoc """
  LiveView `on_mount` hook that applies the UI locale to the LiveView process (M3, ADR 0075). LiveView
  processes do not inherit the Gettext locale the Locale plug set on the request, so the mount must set it
  again from the session value the plug stored. Also assigns `:ui_locale` so components can render
  language-dependent chrome.
  """
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    locale = session["ui_locale"] || MimimiWeb.Plugs.Locale.default()
    Gettext.put_locale(MimimiWeb.Gettext, locale)
    {:cont, assign(socket, :ui_locale, locale)}
  end
end
