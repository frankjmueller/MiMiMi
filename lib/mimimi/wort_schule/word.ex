defmodule Mimimi.WortSchule.Word do
  @moduledoc """
  A playable word from the ourwords delivery view `mimimi.words` (ADR 0075) — read-only. One row per
  published word that has a non-offensive meaning; the id is the stable public word id (source_entry_id).
  `image_url` is a relative ActiveStorage path the game prepends its asset base to. Keywords are a
  separate namespace (sense_relation ids), joined via `mimimi.keywords` — NOT the old self-referential
  word-to-word join. Text passes through verbatim (HR2): never normalize name here.
  """
  use Ecto.Schema

  @schema_prefix "mimimi"
  @primary_key {:id, :id, autogenerate: false}
  schema "words" do
    field :language_iso, :string
    field :name, :string
    field :slug, :string
    field :type, :string
    field :meaning, :string
    field :image_url, :string
    field :direction, :string

    has_many :keywords, Mimimi.WortSchule.Keyword, foreign_key: :word_id, references: :id
  end
end
