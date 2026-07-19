defmodule Mimimi.Repo.Migrations.DropPlayerNickname do
  use Ecto.Migration

  # M4 child-safety (ADR 0075): the free-text nickname is gone — the avatar is the player's identity.
  def change do
    alter table(:players) do
      remove :nickname, :string
    end
  end
end
