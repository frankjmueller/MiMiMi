defmodule Mimimi.WortSchuleTest do
  @moduledoc """
  The WortSchule context now reads the ourwords delivery schema (ADR 0075) — the `mimimi.words` and
  `mimimi.keywords` views — instead of the old flat wort.schule `words` table with its self-referential
  keyword join and its per-word image HTTP call. Keyword ids are sense_relation ids (a namespace of
  their own, NOT word ids); image_url is a relative path the game prepends its asset base to; labels and
  lemmas pass through verbatim (HR2). These tests run against the M0 fixture rebuild — no external DB.
  """
  use Mimimi.DataCase, async: false

  alias Mimimi.WortSchule
  alias Mimimi.OurwordsFixtures

  setup do
    OurwordsFixtures.insert_language("deu", autonym: "Deutsch")
    OurwordsFixtures.insert_language("eng", autonym: "English")
    :ok
  end

  describe "get_word_ids_with_keywords_and_images/1" do
    test "returns words that have an image and at least min_keywords keywords" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf")
      OurwordsFixtures.insert_keywords(1, "deu", ["Wolle", "Weide", "blökt"])
      OurwordsFixtures.insert_word(id: 2, language_iso: "deu", name: "Hund")
      OurwordsFixtures.insert_keywords(2, "deu", ["bellt"])
      OurwordsFixtures.insert_word(id: 3, language_iso: "deu", name: "Bild-los", image_url: nil)
      OurwordsFixtures.insert_keywords(3, "deu", ["a", "b", "c"])

      assert WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 3) == [1]

      assert WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 1) |> Enum.sort() == [
               1,
               2
             ]
    end

    test "filters by word type" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf", type: "Noun")
      OurwordsFixtures.insert_keywords(1, "deu", ["Wolle"])
      OurwordsFixtures.insert_word(id: 2, language_iso: "deu", name: "laufen", type: "Verb")
      OurwordsFixtures.insert_keywords(2, "deu", ["rennen"])

      assert WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 1, types: ["Noun"]) ==
               [1]
    end

    test "filters by language — a game is language-pure" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf")
      OurwordsFixtures.insert_keywords(1, "deu", ["Wolle"])
      OurwordsFixtures.insert_word(id: 2, language_iso: "eng", name: "sheep")
      OurwordsFixtures.insert_keywords(2, "eng", ["wool"])

      assert WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 1, language: "deu") ==
               [1]

      assert WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 1, language: "eng") ==
               [2]
    end
  end

  describe "get_complete_word/1" do
    test "returns keywords keyed by their sense_relation id, with the label as the name" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf")
      [wolle_id, weide_id] = OurwordsFixtures.insert_keywords(1, "deu", ["Wolle", "Weide"])

      assert {:ok, word} = WortSchule.get_complete_word(1)
      assert word.id == 1
      assert word.name == "Schaf"

      assert Enum.sort_by(word.keywords, & &1.id) ==
               Enum.sort_by(
                 [%{id: wolle_id, name: "Wolle"}, %{id: weide_id, name: "Weide"}],
                 & &1.id
               )
    end

    test "prepends the configured asset base url to the relative image path" do
      Application.put_env(:mimimi, :ourwords_asset_base_url, "https://ourwords.example")
      on_exit(fn -> Application.delete_env(:mimimi, :ourwords_asset_base_url) end)

      OurwordsFixtures.insert_word(
        id: 1,
        language_iso: "deu",
        name: "Schaf",
        image_url: "/rails/active_storage/blobs/abc.png"
      )

      OurwordsFixtures.insert_keywords(1, "deu", ["Wolle"])

      assert {:ok, word} = WortSchule.get_complete_word(1)
      assert word.image_url == "https://ourwords.example/rails/active_storage/blobs/abc.png"
    end

    test "an unknown word is {:error, :not_found}" do
      assert WortSchule.get_complete_word(999) == {:error, :not_found}
    end

    test "lemma and labels survive verbatim — diacritics and click letters (HR2)" do
      OurwordsFixtures.insert_word(id: 7, language_iso: "deu", name: "Fußball")

      OurwordsFixtures.insert_keyword(
        keyword_id: 71,
        word_id: 7,
        name: "ǀgôas",
        language_iso: "deu"
      )

      assert {:ok, word} = WortSchule.get_complete_word(7)
      assert word.name == "Fußball"
      assert [%{name: "ǀgôas"}] = word.keywords
    end
  end

  describe "get_keywords_batch/1" do
    test "resolves keyword ids (sense_relation ids) to their labels" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf")
      [wolle_id, weide_id] = OurwordsFixtures.insert_keywords(1, "deu", ["Wolle", "Weide"])

      batch = WortSchule.get_keywords_batch([wolle_id, weide_id])
      assert batch[wolle_id].name == "Wolle"
      assert batch[weide_id].name == "Weide"
    end

    test "an empty list yields an empty map" do
      assert WortSchule.get_keywords_batch([]) == %{}
    end
  end

  describe "get_max_keywords_count/0" do
    test "is the largest keyword count among words that have an image" do
      OurwordsFixtures.insert_word(id: 1, language_iso: "deu", name: "Schaf")
      OurwordsFixtures.insert_keywords(1, "deu", ["a", "b", "c", "d"])
      OurwordsFixtures.insert_word(id: 2, language_iso: "deu", name: "Hund")
      OurwordsFixtures.insert_keywords(2, "deu", ["x"])

      assert WortSchule.get_max_keywords_count() == 4
    end
  end
end
