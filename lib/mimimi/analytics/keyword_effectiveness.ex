defmodule Mimimi.Analytics.KeywordEffectiveness do
  @moduledoc """
  The ourwords-owned analytics table `mimimi.keyword_effectiveness` (ADR 0075) — the single surface the
  game writes to. One row per keyword that was visible when a player made a pick. PII-free: no player,
  session or device reference; the pick/round UUIDs are game-round-opaque. Owned and migrated by
  ourwords/Rails; the game only INSERTs. `keyword_id` is a sense_relation id (not a word id).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "mimimi"

  schema "keyword_effectiveness" do
    # ourwords public ids (integers)
    field :word_id, :integer
    field :keyword_id, :integer
    field :language_iso, :string

    # game-round-opaque UUIDs (not foreign keys — this table lives in the ourwords database)
    field :pick_id, :binary_id
    field :round_id, :binary_id

    # order & timing
    field :keyword_position, :integer
    field :revealed_at, :utc_datetime_usec
    field :picked_at, :utc_datetime_usec

    # outcome
    field :led_to_correct, :boolean

    # ourwords owns the table: it is `created_at`, INSERT-only (no updated_at).
    field :created_at, :utc_datetime_usec
  end

  @required_fields [
    :word_id,
    :keyword_id,
    :language_iso,
    :pick_id,
    :round_id,
    :keyword_position,
    :revealed_at,
    :picked_at,
    :led_to_correct,
    :created_at
  ]

  @doc false
  def changeset(keyword_effectiveness, attrs) do
    keyword_effectiveness
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:keyword_position, 1..5)
  end
end
