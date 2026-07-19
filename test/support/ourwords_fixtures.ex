defmodule Mimimi.OurwordsFixtures do
  @moduledoc """
  Test fixtures for the ourwords delivery schema (ADR 0075): insert languages, words and keywords
  into the fixture rebuild of the `mimimi` schema (see test/support/fixtures/ourwords_mimimi_schema.sql),
  so game and pool logic can be tested deterministically without the real ourwords database.
  Values pass through verbatim — never normalize a lemma or label here.
  """

  alias Mimimi.WortSchuleRepo

  def insert_language(iso, opts \\ []) do
    WortSchuleRepo.query!(
      "INSERT INTO mimimi.fixture_languages (language_iso, autonym, english_name, rtl) " <>
        "VALUES ($1, $2, $3, $4)",
      [
        iso,
        Keyword.get(opts, :autonym, iso),
        Keyword.get(opts, :english_name),
        Keyword.get(opts, :rtl, false)
      ]
    )

    iso
  end

  @doc """
  Inserts a word row. `image_url` defaults to a present (relative) path — pass `image_url: nil`
  for a word without a picture.
  """
  def insert_word(opts) do
    id = Keyword.fetch!(opts, :id)
    name = Keyword.fetch!(opts, :name)

    WortSchuleRepo.query!(
      "INSERT INTO mimimi.words (id, language_iso, name, slug, type, meaning, example_sentences, image_url, direction) " <>
        "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
      [
        id,
        Keyword.fetch!(opts, :language_iso),
        name,
        Keyword.get(opts, :slug, String.downcase(name)),
        Keyword.get(opts, :type, "Noun"),
        Keyword.get(opts, :meaning, "a meaning"),
        Keyword.get(opts, :example_sentences, []),
        Keyword.get(opts, :image_url, "/rails/active_storage/fixture-#{id}.png"),
        Keyword.get(opts, :direction, "ltr")
      ]
    )

    id
  end

  def insert_keyword(opts) do
    keyword_id = Keyword.fetch!(opts, :keyword_id)

    WortSchuleRepo.query!(
      "INSERT INTO mimimi.keywords (keyword_id, word_id, name, language_iso) VALUES ($1, $2, $3, $4)",
      [
        keyword_id,
        Keyword.fetch!(opts, :word_id),
        Keyword.fetch!(opts, :name),
        Keyword.fetch!(opts, :language_iso)
      ]
    )

    keyword_id
  end

  @doc "Inserts several keywords for one word; ids are derived as word_id * 100 + index."
  def insert_keywords(word_id, language_iso, names) do
    names
    |> Enum.with_index(1)
    |> Enum.map(fn {name, index} ->
      insert_keyword(
        keyword_id: word_id * 100 + index,
        word_id: word_id,
        name: name,
        language_iso: language_iso
      )
    end)
  end
end
