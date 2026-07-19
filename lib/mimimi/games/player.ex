defmodule Mimimi.Games.Player do
  @moduledoc """
  Schema for game players. Links users to games with their avatar and score.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "players" do
    field :points, :integer, default: 0

    # The avatar (unique per game) IS the player's identity — there is no free-text nickname a child
    # could type into (M4 child-safety, ADR 0075).
    field :avatar, :string

    belongs_to :user, Mimimi.Accounts.User
    belongs_to :game, Mimimi.Games.Game
    has_many :picks, Mimimi.Games.Pick

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:points, :avatar, :user_id, :game_id])
    |> validate_required([:user_id, :game_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :avatar])
  end
end
