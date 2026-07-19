defmodule MimimiWeb.Plugs.Locale do
  @moduledoc """
  Resolves the UI locale (chrome language) for a request (M3, ADR 0075): the `ui_locale` cookie wins, else
  the best Accept-Language match, else the default "de". Only supported locales are accepted. The resolved
  locale is set as the Gettext locale for this request (controllers), put in the session (so a LiveView's
  mount can read it via LocaleHook), and assigned to the conn (so the root layout's <html lang> is right).

  Note: this is the UI language only. The game's content language is per-game (M2) and independent — a
  German-UI class can play English words.
  """
  import Plug.Conn

  @supported ~w(de en)
  @default "de"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = resolve(conn)

    Gettext.put_locale(MimimiWeb.Gettext, locale)

    conn
    |> put_session("ui_locale", locale)
    |> assign(:ui_locale, locale)
  end

  @doc "The default UI locale."
  def default, do: @default

  @doc "The supported UI locales."
  def supported, do: @supported

  defp resolve(conn) do
    cookie_locale(conn) || accept_language_locale(conn) || @default
  end

  defp cookie_locale(conn) do
    conn.cookies
    |> case do
      %{"ui_locale" => locale} -> supported(locale)
      _ -> nil
    end
  end

  # Parse Accept-Language honouring q-values: sort tags by descending quality (default q=1.0), drop q<=0,
  # then take the first supported base tag (en-US → en). So "de;q=0.1,en;q=1.0" resolves to "en".
  defp accept_language_locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> case do
      nil ->
        nil

      header ->
        header
        |> String.split(",")
        |> Enum.map(&parse_language_range/1)
        |> Enum.reject(fn {_base, q} -> q <= 0.0 end)
        |> Enum.sort_by(fn {_base, q} -> q end, :desc)
        |> Enum.find_value(fn {base, _q} -> supported(base) end)
    end
  end

  # "en-US;q=0.8" → {"en", 0.8}; a missing q defaults to 1.0, an unparseable q to 0.0 (dropped).
  defp parse_language_range(part) do
    [tag | params] = part |> String.trim() |> String.split(";")
    base = tag |> String.trim() |> String.split("-") |> hd() |> String.downcase()

    q =
      params
      |> Enum.find_value(1.0, fn param ->
        case param |> String.trim() |> String.split("=") do
          ["q", value] -> parse_q(value)
          _ -> nil
        end
      end)

    {base, q}
  end

  defp parse_q(value) do
    case Float.parse(String.trim(value)) do
      {q, _rest} -> q
      :error -> 0.0
    end
  end

  defp supported(locale) when locale in @supported, do: locale
  defp supported(_locale), do: nil
end
