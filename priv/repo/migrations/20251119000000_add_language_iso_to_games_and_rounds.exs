defmodule Mimimi.Repo.Migrations.AddLanguageIsoToGamesAndRounds do
  use Ecto.Migration

  # M2: the game language becomes a real field. Additive and rollback-safe — existing games/rounds
  # default to "deu" (M1 was German-only). Rounds carry the language denormalized so analytics and
  # rendering need no game join.
  def change do
    alter table(:games) do
      add :language_iso, :string, null: false, default: "deu"
    end

    alter table(:rounds) do
      add :language_iso, :string, null: false, default: "deu"
    end
  end
end
