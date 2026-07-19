defmodule Mimimi.Games.PlayerTest do
  @moduledoc """
  M4 child-safety (ADR 0075): a player has no free-text nickname. Identity is the avatar (unique per game),
  so there is no free-text field a child could type into. The changeset must not cast `:nickname`.
  """
  use Mimimi.DataCase, async: true

  alias Mimimi.Games.Player

  test "the changeset does not accept a nickname (no free-text player field)" do
    changeset =
      Player.changeset(%Player{}, %{
        avatar: "🐻",
        nickname: "anything",
        user_id: Ecto.UUID.generate(),
        game_id: Ecto.UUID.generate()
      })

    refute Map.has_key?(changeset.changes, :nickname)
  end
end
