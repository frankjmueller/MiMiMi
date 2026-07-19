-- Test rebuild of the ourwords delivery schema `mimimi` (ADR 0075). The COLUMN CONTRACT here is
-- identical to production and pinned by test/mimimi/ourwords_schema_contract_test.exs — change it
-- only together with the ourwords side (docs/adr/0075-mimimi-delivery-schema-and-analytics-backchannel.md).
--
-- Differences to production, on purpose:
--   * `words` and `keywords` are TABLES here (production defines them as read-only views over the
--     ourwords read-model) so fixtures can insert rows directly.
--   * `fixture_languages` replaces the ourwords language registry as the source that feeds
--     `playable_languages`; the view itself keeps the production counter semantics (a counter counts
--     PLAYABLE words: image present + at least one keyword).
--
-- Loaded idempotently by priv/repo/load_ourwords_fixture_schema.exs (part of the `mix test` alias).

DROP SCHEMA IF EXISTS mimimi CASCADE;
CREATE SCHEMA mimimi;

CREATE TABLE mimimi.fixture_languages (
  language_iso varchar PRIMARY KEY,
  autonym varchar NOT NULL,
  english_name varchar,
  rtl boolean NOT NULL DEFAULT false
);

CREATE TABLE mimimi.words (
  id bigint PRIMARY KEY,
  language_iso varchar NOT NULL,
  name varchar NOT NULL,
  slug varchar NOT NULL,
  type text,
  meaning text,
  example_sentences jsonb,
  image_url text,
  direction varchar NOT NULL DEFAULT 'ltr'
);

CREATE TABLE mimimi.keywords (
  keyword_id bigint PRIMARY KEY,
  word_id bigint NOT NULL,
  name text NOT NULL,
  language_iso varchar NOT NULL
);

CREATE TABLE mimimi.keyword_effectiveness (
  id bigserial PRIMARY KEY,
  word_id bigint NOT NULL,
  keyword_id bigint NOT NULL,
  language_iso varchar NOT NULL,
  keyword_position integer NOT NULL,
  revealed_at timestamp(6),
  picked_at timestamp(6),
  led_to_correct boolean NOT NULL,
  pick_id uuid,
  round_id uuid,
  created_at timestamp(6) NOT NULL,
  CONSTRAINT mimimi_keyword_position_range CHECK (keyword_position BETWEEN 1 AND 5)
);

CREATE VIEW mimimi.playable_languages AS
SELECT
  l.language_iso,
  l.autonym,
  l.english_name,
  l.rtl,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 1)                          AS words_with_image_min1_kw,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 3)                          AS words_with_image_min3_kw,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 1 AND w.type = 'Noun')      AS noun_count,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 1 AND w.type = 'Verb')      AS verb_count,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 1 AND w.type = 'Adjective') AS adjective_count,
  COUNT(w.id) FILTER (WHERE kw.kw_count >= 1 AND w.type = 'Adverb')    AS adverb_count
FROM mimimi.fixture_languages l
LEFT JOIN mimimi.words w
  ON w.language_iso = l.language_iso AND COALESCE(w.image_url, '') <> ''
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS kw_count FROM mimimi.keywords k WHERE k.word_id = w.id
) kw ON true
GROUP BY l.language_iso, l.autonym, l.english_name, l.rtl;
