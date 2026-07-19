defmodule Mimimi.AnalyticsTest do
  @moduledoc """
  The analytics writer now targets the ourwords-owned `mimimi.keyword_effectiveness` table (ADR 0075):
  a PII-free aggregate with a bigserial id and a `created_at` column, carrying `language_iso` and the
  game-round-opaque pick/round UUIDs. keyword_id is a sense_relation id (not a word id). These tests run
  against the M0 fixture rebuild — no external DB.
  """
  use Mimimi.DataCase, async: false

  alias Mimimi.Analytics
  alias Mimimi.WortSchuleRepo

  defp rows do
    %{rows: rows, columns: cols} =
      WortSchuleRepo.query!(
        "SELECT word_id, keyword_id, language_iso, keyword_position, led_to_correct, " <>
          "pick_id, round_id, created_at FROM mimimi.keyword_effectiveness ORDER BY keyword_position"
      )

    Enum.map(rows, fn row -> cols |> Enum.zip(row) |> Map.new() end)
  end

  describe "record_pick_effectiveness/7" do
    test "writes one row per shown keyword, carrying the language and outcome" do
      round_id = Ecto.UUID.generate()
      pick_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      keywords = [
        {101, 1, DateTime.add(now, -30, :second)},
        {102, 2, DateTime.add(now, -20, :second)}
      ]

      assert {2, _} =
               Analytics.record_pick_effectiveness(
                 round_id,
                 pick_id,
                 42,
                 "deu",
                 keywords,
                 now,
                 true
               )

      written = rows()
      assert length(written) == 2
      assert Enum.map(written, & &1["keyword_position"]) == [1, 2]
      assert Enum.all?(written, &(&1["language_iso"] == "deu"))
      assert Enum.all?(written, &(&1["word_id"] == 42))
      assert Enum.all?(written, &(&1["led_to_correct"] == true))
      assert Enum.all?(written, &(&1["created_at"] != nil))
    end

    test "the reveal-step CHECK (1..5) is enforced by the ourwords table" do
      round_id = Ecto.UUID.generate()
      pick_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      assert_raise Postgrex.Error, ~r/keyword_position/, fn ->
        Analytics.record_pick_effectiveness(
          round_id,
          pick_id,
          42,
          "deu",
          [{101, 9, now}],
          now,
          true
        )
      end
    end
  end
end
