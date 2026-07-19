defmodule MimimiWeb.GameComponentsBidiTest do
  @moduledoc """
  HR2 (ADR 0075): lemmas and keywords render VERBATIM and bidi-aware — every name sits inside a
  `<bdi lang=… dir="auto">` so RTL scripts lay out correctly and diacritics / click letters survive
  byte-for-byte. No CSS uppercasing or normalization is applied to a name.
  """
  use MimimiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MimimiWeb.GameComponents

  test "a revealed keyword renders verbatim inside a bdi carrying the content language" do
    html =
      render_component(&keyword_badges/1,
        keywords: [%{id: 1, name: "ǀgôas"}],
        revealed: 1,
        language_iso: "naq"
      )

    assert html =~ ~s(<bdi lang="naq" dir="auto">ǀgôas</bdi>)
  end

  test "an Arabic word label renders inside a bdi (RTL lays out from the dir=auto)" do
    html =
      render_component(&word_card/1,
        word: %{id: 1, name: "قطة", image_url: nil},
        show_label: true,
        language_iso: "arb"
      )

    assert html =~ ~s(<bdi lang="arb" dir="auto">قطة</bdi>)
  end

  test "an unrevealed keyword shows the mask, never the name" do
    html =
      render_component(&keyword_badge/1,
        keyword: %{id: 1, name: "Geheimnis"},
        index: 3,
        keywords_revealed: 0,
        time_elapsed: 0,
        clues_interval: 9,
        language_iso: "deu"
      )

    refute html =~ "Geheimnis"
    assert html =~ "???"
  end
end
