defmodule Mimimi.Games.RoundValidationTest do
  @moduledoc """
  Round generation now draws from the ourwords delivery views (ADR 0075): the words pool is guaranteed
  to have images (image_url is a WHERE clause in the view), so the old per-word image HTTP validation is
  gone. Keywords are resolved via the keywords view (sense_relation ids), never the words view. These
  tests run against the M0 fixtures — deterministic, no external DB, no network.
  """
  use Mimimi.DataCase, async: false

  alias Mimimi.{Accounts, Games}
  alias Mimimi.OurwordsFixtures

  # Seed a pool large enough for a small game: nouns with an image, some with 3+ keywords (targets),
  # all with at least one (distractors).
  defp seed_pool do
    OurwordsFixtures.insert_language("deu", autonym: "Deutsch")

    for id <- 1..8 do
      OurwordsFixtures.insert_word(id: id, language_iso: "deu", name: "Wort#{id}", type: "Noun")
      OurwordsFixtures.insert_keywords(id, "deu", ["k#{id}a", "k#{id}b", "k#{id}c"])
    end
  end

  describe "generate_rounds/1 against the delivery views" do
    setup do
      {:ok, host} = Accounts.get_or_create_user_by_session("round_gen_host")
      %{host: host}
    end

    test "creates the requested rounds, each with an image-backed word and resolvable keywords",
         %{host: host} do
      seed_pool()

      {:ok, game} =
        Games.create_game(host.id, %{
          rounds_count: 2,
          clues_interval: 9,
          grid_size: 4,
          word_types: ["Noun"]
        })

      Games.generate_rounds(game)

      rounds =
        Repo.all(
          from(r in Games.Round, where: r.game_id == ^game.id, order_by: [asc: r.position])
        )

      assert length(rounds) == 2

      Enum.each(rounds, fn round ->
        # Every keyword id resolves to a non-empty label via the keywords view (not the words view).
        assert length(round.keyword_ids) >= 3
        keywords = Mimimi.WortSchule.get_keywords_batch(round.keyword_ids)

        Enum.each(round.keyword_ids, fn kid ->
          assert %{name: name} = Map.get(keywords, kid)
          assert name not in [nil, ""]
        end)

        # The target word has an image in the words view.
        assert {:ok, %{image_url: image_url}} = Mimimi.WortSchule.get_complete_word(round.word_id)
        assert is_binary(image_url) and image_url != ""
      end)
    end

    test "the pool is language-pure — a German game never draws a word of another language", %{
      host: host
    } do
      seed_pool()

      # An equally playable English pool sitting alongside — it must never enter a German game (M1).
      OurwordsFixtures.insert_language("eng", autonym: "English")

      for id <- 101..108 do
        OurwordsFixtures.insert_word(id: id, language_iso: "eng", name: "word#{id}", type: "Noun")
        OurwordsFixtures.insert_keywords(id, "eng", ["k#{id}a", "k#{id}b", "k#{id}c"])
      end

      {:ok, game} =
        Games.create_game(host.id, %{
          rounds_count: 2,
          clues_interval: 9,
          grid_size: 4,
          word_types: ["Noun"]
        })

      Games.generate_rounds(game)

      rounds = Repo.all(from(r in Games.Round, where: r.game_id == ^game.id))
      all_word_ids = Enum.flat_map(rounds, & &1.possible_words_ids)

      %{rows: languages} =
        Mimimi.WortSchuleRepo.query!(
          "SELECT DISTINCT language_iso FROM mimimi.words WHERE id = ANY($1)",
          [all_word_ids]
        )

      assert List.flatten(languages) == ["deu"], "target and distractors must all be German"
    end
  end

  describe "insufficient data raises an informative error" do
    setup do
      {:ok, host} = Accounts.get_or_create_user_by_session("insufficient_host")
      %{host: host}
    end

    test "not enough target words", %{host: host} do
      # No fixtures seeded → the pool is empty.
      {:ok, game} =
        Games.create_game(host.id, %{
          rounds_count: 20,
          clues_interval: 9,
          grid_size: 9,
          word_types: ["Noun"]
        })

      assert_raise RuntimeError, ~r/nicht genügend|not enough/i, fn ->
        Games.generate_rounds(game)
      end
    end
  end
end
