defmodule Mimimi.WortSchule do
  @moduledoc """
  Context for reading the ourwords delivery schema (ADR 0075): the read-only views `mimimi.words` and
  `mimimi.keywords`. Words carry a relative `image_url` (the game prepends its asset base — no per-word
  HTTP call anymore); keywords are a separate id namespace (sense_relation ids). Everything here is
  read-only and language-aware. Text passes through verbatim (HR2).
  """
  import Ecto.Query
  alias Mimimi.WortSchuleRepo, as: Repo
  alias Mimimi.WortSchule.Word
  # Aliased as KeywordView so it does not shadow Elixir's stdlib `Keyword` (used for opts below).
  alias Mimimi.WortSchule.Keyword, as: KeywordView

  @doc """
  Get complete word data: id, name, keywords (as `%{id: sense_relation_id, name: label}`), and the
  absolute image URL. Returns `{:error, :not_found}` for an unknown id.
  """
  def get_complete_word(word_id) do
    case get_word_with_keywords(word_id) do
      nil -> {:error, :not_found}
      word -> {:ok, format_word(word)}
    end
  end

  @doc "Batch variant of `get_complete_word/1`, returning a map of `word_id => complete word data`."
  def get_complete_words_batch([]), do: %{}

  def get_complete_words_batch(word_ids) when is_list(word_ids) do
    from(w in Word,
      where: w.id in ^word_ids,
      preload: [keywords: ^from(k in KeywordView, order_by: k.name)]
    )
    |> Repo.all()
    |> Enum.map(fn word -> {word.id, format_word(word)} end)
    |> Enum.into(%{})
  end

  @doc "Get a word by id (no keywords)."
  def get_word(id), do: Repo.get(Word, id)

  @doc "Get a word by slug."
  def get_word_by_slug(slug), do: Repo.get_by(Word, slug: slug)

  @doc "Get a word with its keywords preloaded (ordered by label)."
  def get_word_with_keywords(id) do
    from(w in Word,
      where: w.id == ^id,
      preload: [keywords: ^from(k in KeywordView, order_by: k.name)]
    )
    |> Repo.one()
  end

  @doc """
  Resolve keyword ids (sense_relation ids) to `%{keyword_id => %{id:, name:}}`. This is the correct
  lookup for round keyword_ids — they are NOT word ids and must never be resolved via the words view.
  """
  def get_keywords_batch([]), do: %{}

  def get_keywords_batch(keyword_ids) when is_list(keyword_ids) do
    from(k in KeywordView, where: k.keyword_id in ^keyword_ids)
    |> Repo.all()
    |> Enum.map(fn keyword ->
      {keyword.keyword_id, %{id: keyword.keyword_id, name: keyword.name}}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Ids of all words that have an image and at least `:min_keywords` keywords, ordered by name.

  ## Options

    * `:min_keywords` - minimum keyword count (default 1)
    * `:types` - list of word types to include (e.g. `["Noun"]`); all types when omitted
    * `:language` - restrict to one language (iso_639_3, e.g. `"deu"`); all languages when omitted
  """
  def get_word_ids_with_keywords_and_images(opts \\ []) do
    min_keywords = Keyword.get(opts, :min_keywords, 1)
    types = Keyword.get(opts, :types)
    language = Keyword.get(opts, :language)

    query =
      from(w in Word,
        join: k in KeywordView,
        on: k.word_id == w.id,
        where: not is_nil(w.image_url) and w.image_url != "",
        group_by: [w.id, w.name],
        having: count(k.keyword_id) >= ^min_keywords,
        order_by: w.name,
        select: {w.id, w.name}
      )

    query = if types && types != [], do: from(w in query, where: w.type in ^types), else: query
    query = if language, do: from(w in query, where: w.language_iso == ^language), else: query

    query
    |> Repo.all()
    |> Enum.map(fn {id, _name} -> id end)
  end

  @doc """
  The largest keyword count among words that have an image (0 when there are none). Bounds the
  „minimum keywords" slider in the word list.

  ## Options

    * `:language` - restrict to one language (iso_639_3); all languages when omitted
  """
  def get_max_keywords_count(opts \\ []) do
    language = Keyword.get(opts, :language)

    query =
      from(w in Word,
        join: k in KeywordView,
        on: k.word_id == w.id,
        where: not is_nil(w.image_url) and w.image_url != "",
        group_by: w.id,
        select: count(k.keyword_id)
      )

    query = if language, do: from(w in query, where: w.language_iso == ^language), else: query

    case Repo.all(query) do
      [] -> 0
      counts -> Enum.max(counts)
    end
  end

  @doc """
  List words with optional filters.

  ## Options

    * `:type` - filter by word type
    * `:language` - filter by language (iso_639_3)
    * `:limit` - default 100
    * `:offset` - default 0
  """
  def list_words(opts \\ []) do
    type = Keyword.get(opts, :type)
    language = Keyword.get(opts, :language)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query = from(w in Word, order_by: w.name)
    query = if type, do: from(w in query, where: w.type == ^type), else: query
    query = if language, do: from(w in query, where: w.language_iso == ^language), else: query

    query
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  The languages that have at least one playable word (image + keywords), from `mimimi.playable_languages`.
  Each is `%{language_iso, autonym, english_name, rtl, words_with_image_min1_kw, words_with_image_min3_kw,
  noun_count, verb_count, adjective_count, adverb_count}`. The lobby offers only these.
  """
  def playable_languages do
    %{columns: cols, rows: rows} =
      Repo.query!("""
      SELECT language_iso, autonym, english_name, rtl,
             words_with_image_min1_kw, words_with_image_min3_kw,
             noun_count, verb_count, adjective_count, adverb_count
      FROM mimimi.playable_languages
      WHERE words_with_image_min1_kw > 0
      ORDER BY autonym
      """)

    keys = Enum.map(cols, &String.to_atom/1)
    Enum.map(rows, fn row -> keys |> Enum.zip(row) |> Map.new() end)
  end

  # Keywords are `%{id: sense_relation_id, name: label}`; image_url is the relative delivery path with
  # the asset base prepended (empty base → path passes through unchanged).
  defp format_word(word) do
    %{
      id: word.id,
      name: word.name,
      keywords: Enum.map(word.keywords, &%{id: &1.keyword_id, name: &1.name}),
      image_url: absolute_image_url(word.image_url)
    }
  end

  defp absolute_image_url(nil), do: nil

  defp absolute_image_url(path) do
    case Application.get_env(:mimimi, :ourwords_asset_base_url, "") do
      "" -> path
      base -> base <> path
    end
  end
end
