defmodule MimimiWeb.InternalPages do
  @moduledoc """
  M4 child-safety (ADR 0075): /debug and /list_words expose internal ids and statistics. They are gated
  behind the `:internal_pages` config flag — safe-by-default OFF, so production never serves them unless a
  deployment explicitly opts in. A LiveView guards its `mount/3` with `guard/1`, redirecting a visitor to
  the home page when the pages are disabled — internals are never rendered.
  """

  import Phoenix.LiveView, only: [push_navigate: 2]

  @doc "True when internal pages are enabled for this environment (default: false)."
  def enabled?, do: Application.get_env(:mimimi, :internal_pages, false)

  @doc """
  Wrap a LiveView `mount/3` body. Runs `fun` and returns its `{:ok, socket}` when internal pages are
  enabled; otherwise redirects to the home page.
  """
  def guard(socket, fun) do
    if enabled?() do
      fun.()
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end
end
