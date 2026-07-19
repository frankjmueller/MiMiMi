defmodule Mimimi.Analytics do
  @moduledoc """
  Context module for keyword effectiveness analytics.

  Tracks which keywords help players guess words correctly and quickly,
  enabling data-driven improvement of keyword quality.
  """
  import Ecto.Query
  alias Mimimi.WortSchuleRepo
  alias Mimimi.Analytics.KeywordEffectiveness

  @doc """
  Records keyword effectiveness data for a player's pick into the ourwords-owned
  `mimimi.keyword_effectiveness` table (ADR 0075). One row per keyword that was visible when the player
  guessed. The row is PII-free; keyword_id is a sense_relation id.

  ## Parameters

    - `round_id` - game-round-opaque UUID of the round
    - `pick_id` - game-round-opaque UUID of the pick
    - `word_id` - ourwords public id of the target word
    - `language_iso` - the round's language (iso_639_3, e.g. `"deu"`)
    - `keywords_with_timestamps` - list of `{keyword_id, position, revealed_at}` tuples
    - `picked_at` - DateTime when the player guessed
    - `is_correct` - whether the guess was correct

  ## Example

      record_pick_effectiveness(
        round_id,
        pick_id,
        word_id,
        "deu",
        [{123, 1, ~U[2024-01-01 12:00:00Z]}, {456, 2, ~U[2024-01-01 12:00:10Z]}],
        ~U[2024-01-01 12:00:15Z],
        true
      )
  """
  def record_pick_effectiveness(
        round_id,
        pick_id,
        word_id,
        language_iso,
        keywords_with_timestamps,
        picked_at,
        is_correct
      ) do
    now = DateTime.utc_now()

    # No `id`: the ourwords table has a bigserial primary key that Postgres fills. `created_at` is the
    # table's own timestamp column (INSERT-only, no updated_at).
    records =
      Enum.map(keywords_with_timestamps, fn {keyword_id, position, revealed_at} ->
        %{
          word_id: word_id,
          keyword_id: keyword_id,
          language_iso: language_iso,
          pick_id: pick_id,
          round_id: round_id,
          keyword_position: position,
          revealed_at: revealed_at,
          picked_at: picked_at,
          led_to_correct: is_correct,
          created_at: now
        }
      end)

    WortSchuleRepo.insert_all(KeywordEffectiveness, records)
  end

  @doc """
  Gets keyword effectiveness statistics for a specific word.

  Returns stats for each keyword including success rate and average time to guess.
  """
  def get_keyword_stats_for_word(word_id) do
    from(ke in KeywordEffectiveness,
      where: ke.word_id == ^word_id,
      group_by: ke.keyword_id,
      select: %{
        keyword_id: ke.keyword_id,
        total_shown: count(ke.id),
        times_correct: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", ke.led_to_correct)),
        avg_time_ms:
          avg(
            fragment(
              "EXTRACT(EPOCH FROM (? - ?)) * 1000",
              ke.picked_at,
              ke.revealed_at
            )
          )
      }
    )
    |> WortSchuleRepo.all()
    |> Enum.map(fn stat ->
      Map.put(
        stat,
        :success_rate,
        if(stat.total_shown > 0, do: stat.times_correct / stat.total_shown, else: 0.0)
      )
    end)
  end

  @doc """
  Gets words with high failure rate even when all keywords are shown.

  Returns words where players frequently fail despite seeing all available keywords.
  """
  def get_problematic_words(min_attempts \\ 10, min_failure_rate \\ 0.5) do
    # This query finds picks where the player saw the last keyword (highest position)
    # and still guessed incorrectly
    query = """
    WITH max_positions AS (
      SELECT round_id, MAX(keyword_position) as max_pos
      FROM mimimi.keyword_effectiveness
      GROUP BY round_id
    ),
    final_keyword_picks AS (
      SELECT ke.word_id, ke.led_to_correct
      FROM mimimi.keyword_effectiveness ke
      JOIN max_positions mp ON ke.round_id = mp.round_id
        AND ke.keyword_position = mp.max_pos
    )
    SELECT
      word_id,
      COUNT(*) as total_attempts,
      SUM(CASE WHEN NOT led_to_correct THEN 1 ELSE 0 END) as failures,
      SUM(CASE WHEN NOT led_to_correct THEN 1 ELSE 0 END)::float / COUNT(*) as failure_rate
    FROM final_keyword_picks
    GROUP BY word_id
    HAVING COUNT(*) >= $1
      AND SUM(CASE WHEN NOT led_to_correct THEN 1 ELSE 0 END)::float / COUNT(*) >= $2
    ORDER BY failure_rate DESC
    """

    WortSchuleRepo.query!(query, [min_attempts, min_failure_rate])
    |> Map.get(:rows)
    |> Enum.map(fn [word_id, total, failures, rate] ->
      %{
        word_id: word_id,
        total_attempts: total,
        failures: failures,
        failure_rate: rate
      }
    end)
  end

  @doc """
  Gets keywords ranked by effectiveness (best first).

  Effectiveness is measured by success rate and speed of correct guesses.
  """
  def get_best_keywords_for_word(word_id, limit \\ 10) do
    from(ke in KeywordEffectiveness,
      where: ke.word_id == ^word_id and ke.led_to_correct == true,
      group_by: ke.keyword_id,
      having: count(ke.id) >= 5,
      select: %{
        keyword_id: ke.keyword_id,
        times_led_to_correct: count(ke.id),
        avg_time_ms:
          avg(
            fragment(
              "EXTRACT(EPOCH FROM (? - ?)) * 1000",
              ke.picked_at,
              ke.revealed_at
            )
          )
      },
      order_by: [
        asc: avg(fragment("EXTRACT(EPOCH FROM (? - ?)) * 1000", ke.picked_at, ke.revealed_at))
      ],
      limit: ^limit
    )
    |> WortSchuleRepo.all()
  end

  @doc """
  Gets keywords ranked by ineffectiveness (worst first).

  Identifies keywords that are shown but don't help players guess correctly.
  """
  def get_worst_keywords_for_word(word_id, limit \\ 10) do
    from(ke in KeywordEffectiveness,
      where: ke.word_id == ^word_id,
      group_by: ke.keyword_id,
      having: count(ke.id) >= 5,
      select: %{
        keyword_id: ke.keyword_id,
        total_shown: count(ke.id),
        times_correct: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", ke.led_to_correct)),
        success_rate:
          fragment(
            "SUM(CASE WHEN ? THEN 1.0 ELSE 0.0 END) / COUNT(*)",
            ke.led_to_correct
          )
      },
      order_by: [
        asc: fragment("SUM(CASE WHEN ? THEN 1.0 ELSE 0.0 END) / COUNT(*)", ke.led_to_correct)
      ],
      limit: ^limit
    )
    |> WortSchuleRepo.all()
  end
end
