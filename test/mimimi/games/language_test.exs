defmodule Mimimi.Games.LanguageTest do
  @moduledoc """
  M2: the game language is a real per-game field (ADR 0075). The lobby offers only playable languages
  (from mimimi.playable_languages), the word pool is filtered to the chosen language, rounds inherit it
  (denormalized), analytics record it, and „Other" is no longer a selectable word type (the delivery view
  only carries Noun/Verb/Adjective/Adverb).
  """
  use Mimimi.DataCase, async: false

  alias Mimimi.{Accounts, Games, WortSchule}
  alias Mimimi.OurwordsFixtures

  # Distinct id ranges per language so pools never collide.
  defp base_id("deu"), do: 1_000
  defp base_id("eng"), do: 2_000
  defp base_id(_other), do: 8_000

  defp seed_language(iso, autonym, count) do
    OurwordsFixtures.insert_language(iso, autonym: autonym)

    for n <- 1..count do
      id = base_id(iso) + n
      OurwordsFixtures.insert_word(id: id, language_iso: iso, name: "#{iso}#{n}", type: "Noun")
      OurwordsFixtures.insert_keywords(id, iso, ["a#{id}", "b#{id}", "c#{id}"])
      id
    end
  end

  describe "WortSchule.playable_languages/0" do
    test "lists only languages that have a playable word, with autonym and rtl" do
      seed_language("deu", "Deutsch", 3)
      # A language with words but none playable (no keywords) must not appear.
      OurwordsFixtures.insert_language("fra", autonym: "Français")
      OurwordsFixtures.insert_word(id: 9001, language_iso: "fra", name: "chat", type: "Noun")

      langs = WortSchule.playable_languages()
      isos = Enum.map(langs, & &1.language_iso)

      assert "deu" in isos
      refute "fra" in isos
      deu = Enum.find(langs, &(&1.language_iso == "deu"))
      assert deu.autonym == "Deutsch"
      assert deu.rtl == false
    end

    test "reports rtl languages" do
      OurwordsFixtures.insert_language("arb", autonym: "العربية", rtl: true)
      OurwordsFixtures.insert_word(id: 9100, language_iso: "arb", name: "قطة", type: "Noun")
      OurwordsFixtures.insert_keywords(9100, "arb", ["a", "b", "c"])

      arb = Enum.find(WortSchule.playable_languages(), &(&1.language_iso == "arb"))
      assert arb.rtl == true
      assert arb.autonym == "العربية"
    end
  end

  describe "a game carries its language and rounds inherit it" do
    setup do
      {:ok, host} = Accounts.get_or_create_user_by_session("lang_host")
      %{host: host}
    end

    test "the round pool and rounds follow the game's language, not a hardcoded default", %{host: host} do
      seed_language("eng", "English", 8)
      # German words exist too, but an English game must stay English.
      seed_language("deu", "Deutsch", 8)

      {:ok, game} =
        Games.create_game(host.id, %{
          rounds_count: 2,
          clues_interval: 9,
          grid_size: 4,
          word_types: ["Noun"],
          language_iso: "eng"
        })

      assert game.language_iso == "eng"
      Games.generate_rounds(game)

      rounds = Repo.all(from(r in Games.Round, where: r.game_id == ^game.id))
      assert Enum.all?(rounds, &(&1.language_iso == "eng"))

      all_ids = Enum.flat_map(rounds, & &1.possible_words_ids)

      %{rows: languages} =
        Mimimi.WortSchuleRepo.query!(
          "SELECT DISTINCT language_iso FROM mimimi.words WHERE id = ANY($1)",
          [all_ids]
        )

      assert List.flatten(languages) == ["eng"]
    end

    test "a rematch keeps the language", %{host: host} do
      seed_language("deu", "Deutsch", 8)

      {:ok, game} =
        Games.create_game(host.id, %{
          rounds_count: 1,
          clues_interval: 9,
          grid_size: 4,
          word_types: ["Noun"],
          language_iso: "deu"
        })

      {:ok, rematch} = Games.create_new_game_with_players(game)
      assert rematch.language_iso == "deu"
    end
  end

  describe "word type validation" do
    setup do
      {:ok, host} = Accounts.get_or_create_user_by_session("wordtype_host")
      %{host: host}
    end

    test "the Other type is no longer accepted (view carries only Noun/Verb/Adjective/Adverb)", %{host: host} do
      assert {:error, changeset} =
               Games.create_game(host.id, %{
                 rounds_count: 1,
                 clues_interval: 9,
                 grid_size: 4,
                 word_types: ["Other"],
                 language_iso: "deu"
               })

      assert %{word_types: [_ | _]} = errors_on(changeset)
    end
  end
end
