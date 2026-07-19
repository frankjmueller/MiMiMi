defmodule MimimiWeb.ListWordsBidiTest do
  @moduledoc """
  HR2 (ADR 0075): even on the internal /list_words browser, every word lemma and keyword renders verbatim
  inside a `<bdi lang=… dir="auto">` carrying that word's own language (the list spans languages, so the
  language is per-word). Internal pages are enabled in test.
  """
  use MimimiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Mimimi.{Accounts, OurwordsFixtures}

  setup %{conn: conn} do
    {:ok, _user} = Accounts.get_or_create_user_by_session("list_words_session")
    conn = Plug.Test.init_test_session(conn, %{"session_id" => "list_words_session"})
    OurwordsFixtures.insert_language("naq", autonym: "Khoekhoegowab")
    OurwordsFixtures.insert_word(id: 4242, language_iso: "naq", name: "ǀgôas", type: "Noun")

    OurwordsFixtures.insert_keyword(
      keyword_id: 71,
      word_id: 4242,
      name: "ǂharas",
      language_iso: "naq"
    )

    %{conn: conn}
  end

  test "the lemma and its keyword render verbatim inside a bdi with the word's language", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/list_words")
    # Words load via a spawned task that streams messages back — poll the render until it arrives.
    html = wait_for(view, ~s(<bdi lang="naq" dir="auto">ǀgôas</bdi>))

    assert html =~ ~s(<bdi lang="naq" dir="auto">ǀgôas</bdi>)
    assert html =~ ~s(<bdi lang="naq" dir="auto">ǂharas</bdi>)
  end

  defp wait_for(view, needle, tries \\ 40) do
    html = render(view)

    cond do
      html =~ needle -> html
      tries == 0 -> flunk("timed out waiting for #{needle}")
      true -> Process.sleep(25) && wait_for(view, needle, tries - 1)
    end
  end
end
