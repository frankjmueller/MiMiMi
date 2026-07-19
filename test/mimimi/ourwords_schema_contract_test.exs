defmodule Mimimi.OurwordsSchemaContractTest do
  @moduledoc """
  Pins the ourwords delivery contract (ADR 0075) that MiMiMi consumes: the `mimimi` schema with the
  `words` / `keywords` / `playable_languages` views and the single writable `keyword_effectiveness`
  table. In production these live in the ourwords database; in test a fixture rebuild with the SAME
  column contract is loaded (see test/support/fixtures/ourwords_mimimi_schema.sql). If ourwords
  changes the contract, this test is the tripwire — the fixture file and this test change together
  with the ourwords side, never alone.
  """
  use Mimimi.DataCase, async: false

  alias Mimimi.OurwordsFixtures

  # Column lists sorted alphabetically — exactly what information_schema returns below.
  @words_columns ~w(direction example_sentences id image_url language_iso meaning name slug type)
  @keywords_columns ~w(keyword_id language_iso name word_id)
  @playable_columns ~w(adjective_count adverb_count autonym english_name language_iso noun_count rtl verb_count words_with_image_min1_kw words_with_image_min3_kw)
  @effectiveness_columns ~w(created_at id keyword_id keyword_position language_iso led_to_correct pick_id picked_at revealed_at round_id word_id)

  defp columns_of(relation) do
    %{rows: rows} =
      Mimimi.WortSchuleRepo.query!(
        "SELECT column_name FROM information_schema.columns " <>
          "WHERE table_schema = 'mimimi' AND table_name = $1 ORDER BY column_name",
        [relation]
      )

    List.flatten(rows)
  end

  test "mimimi.words carries the ADR-0075 contract columns" do
    assert columns_of("words") == @words_columns
  end

  test "mimimi.keywords carries the ADR-0075 contract columns" do
    assert columns_of("keywords") == @keywords_columns
  end

  test "mimimi.playable_languages carries the ADR-0075 contract columns" do
    assert columns_of("playable_languages") == @playable_columns
  end

  test "mimimi.keyword_effectiveness carries the ADR-0075 contract columns" do
    assert columns_of("keyword_effectiveness") == @effectiveness_columns
  end

  test "fixture words and keywords feed the playable_languages counters" do
    OurwordsFixtures.insert_language("deu", autonym: "Deutsch")
    OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf", type: "Noun")
    OurwordsFixtures.insert_keywords(1, "deu", ["Wolle", "Weide", "blökt"])
    OurwordsFixtures.insert_word(id: 2, language_iso: "deu", name: "Hund", type: "Noun")
    OurwordsFixtures.insert_keywords(2, "deu", ["bellt"])
    OurwordsFixtures.insert_word(id: 3, language_iso: "deu", name: "leer", type: "Adjective", image_url: nil)

    %{rows: [[min1, min3, nouns]]} =
      Mimimi.WortSchuleRepo.query!(
        "SELECT words_with_image_min1_kw, words_with_image_min3_kw, noun_count " <>
          "FROM mimimi.playable_languages WHERE language_iso = 'deu'"
      )

    assert min1 == 2
    assert min3 == 1
    assert nouns == 2
  end

  test "an RTL language carries rtl = true" do
    OurwordsFixtures.insert_language("arb", autonym: "العربية", rtl: true)

    %{rows: [[true]]} =
      Mimimi.WortSchuleRepo.query!(
        "SELECT rtl FROM mimimi.playable_languages WHERE language_iso = 'arb'"
      )
  end

  test "keyword_effectiveness accepts the game's insert shape and enforces the position CHECK" do
    Mimimi.WortSchuleRepo.query!(
      "INSERT INTO mimimi.keyword_effectiveness " <>
        "(word_id, keyword_id, language_iso, keyword_position, led_to_correct, created_at) " <>
        "VALUES (1, 11, 'deu', 3, true, now())"
    )

    assert_raise Postgrex.Error, ~r/keyword_position/, fn ->
      Mimimi.WortSchuleRepo.query!(
        "INSERT INTO mimimi.keyword_effectiveness " <>
          "(word_id, keyword_id, language_iso, keyword_position, led_to_correct, created_at) " <>
          "VALUES (1, 11, 'deu', 9, true, now())"
      )
    end
  end

  test "verbatim text survives the fixture path untouched — diacritics and click letters" do
    OurwordsFixtures.insert_language("naq", autonym: "Khoekhoegowab")
    OurwordsFixtures.insert_word(id: 7, language_iso: "naq", name: "ǀgôas", type: "Noun")

    %{rows: [[name]]} =
      Mimimi.WortSchuleRepo.query!("SELECT name FROM mimimi.words WHERE id = 7")

    assert name == "ǀgôas"
  end
end
