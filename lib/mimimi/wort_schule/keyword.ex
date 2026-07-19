defmodule Mimimi.WortSchule.Keyword do
  @moduledoc """
  A published keyword from the ourwords delivery view `mimimi.keywords` (ADR 0075) — read-only. The
  primary key `keyword_id` is the sense_relation id (a namespace of its own, never a word id); `name`
  is the label, passed through verbatim (HR2). One word has many keywords via `word_id`.
  """
  use Ecto.Schema

  @schema_prefix "mimimi"
  @primary_key {:keyword_id, :id, autogenerate: false}
  schema "keywords" do
    field :word_id, :integer
    field :name, :string
    field :language_iso, :string
  end
end
