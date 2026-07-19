# :external_db tests ran against a live wort.schule database — that data path is being replaced by
# the ourwords fixture schema (ADR 0075); the remaining tagged tests are rewritten against fixtures
# in the connection phase and stay excluded until then.
ExUnit.start(exclude: [:external_db])
Ecto.Adapters.SQL.Sandbox.mode(Mimimi.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Mimimi.WortSchuleRepo, :manual)
