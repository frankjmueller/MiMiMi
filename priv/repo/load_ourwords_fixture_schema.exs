# Loads the fixture rebuild of the ourwords delivery schema (ADR 0075) into the words test
# database. Idempotent (the SQL file starts with DROP SCHEMA IF EXISTS ... CASCADE); wired into
# the `mix test` alias in mix.exs, after the words test database has been created.
# The repo runs with the SQL sandbox pool in test — switch to :auto so this script's DDL commits
# for real (the schema must persist; individual tests roll back only their own inserts).
Ecto.Adapters.SQL.Sandbox.mode(Mimimi.WortSchuleRepo, :auto)

sql = File.read!(Path.join([File.cwd!(), "test", "support", "fixtures", "ourwords_mimimi_schema.sql"]))

# Statements are separated by blank-line-free semicolons; Postgrex runs one statement per query,
# so split on semicolon at line ends (the file contains no semicolons inside literals).
sql
|> String.split(~r/;\s*\n/, trim: true)
|> Enum.reject(&(String.trim(&1) == ""))
|> Enum.each(fn statement -> Mimimi.WortSchuleRepo.query!(statement, [], timeout: 15_000) end)

IO.puts("ourwords fixture schema loaded into the words test database")
