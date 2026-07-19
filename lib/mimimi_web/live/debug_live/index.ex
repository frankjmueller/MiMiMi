defmodule MimimiWeb.DebugLive.Index do
  use MimimiWeb, :live_view
  alias Mimimi.WortSchuleRepo, as: Repo

  # Reads the ourwords delivery views (ADR 0075) for a quick health/stats readout. No image URL cache
  # anymore (the view carries image_url directly). M4 puts this page behind staff-only access in prod.

  @impl true
  def mount(_params, _session, socket) do
    # Child-safety gate (M4): off in production unless explicitly enabled.
    MimimiWeb.InternalPages.guard(socket, fn ->
      socket =
        if connected?(socket) do
          socket
          |> assign(:loading, false)
          |> assign(:system_info, get_system_info())
          |> load_database_stats()
        else
          socket
          |> assign(:loading, true)
          |> assign(:system_info, get_system_info())
        end

      {:ok, assign(socket, :page_title, "ourwords Debug")}
    end)
  end

  defp get_system_info do
    %{
      elixir_version: System.version(),
      erlang_version: get_erlang_version(),
      phoenix_version: Application.spec(:phoenix, :vsn) |> to_string(),
      app_version: Application.spec(:mimimi, :vsn) |> to_string(),
      deployment_timestamp: get_deployment_timestamp()
    }
  end

  defp get_erlang_version do
    system_version = :erlang.system_info(:system_version) |> to_string()

    case Regex.run(~r/Erlang\/OTP \d+ \[erts-([\d.]+)\]/, system_version) do
      [_, erts_version] ->
        case String.split(erts_version, ".") do
          [_major, minor | _] -> "#{System.otp_release()}.#{minor}"
          _ -> System.otp_release()
        end

      _ ->
        System.otp_release()
    end
  end

  defp get_deployment_timestamp do
    Application.get_env(:mimimi, :build_timestamp) || get_beam_compile_time()
  end

  defp get_beam_compile_time do
    with path when is_list(path) <- :code.which(Mimimi.Application),
         {:ok, %{mtime: mtime}} <- File.stat(path) do
      mtime
      |> NaiveDateTime.from_erl!()
      |> DateTime.from_naive!("Etc/UTC")
      |> Calendar.strftime("%d.%m.%Y %H:%M:%S UTC")
    else
      _ -> "Unknown"
    end
  end

  defp load_database_stats(socket) do
    stats = %{
      connection_status: check_connection(),
      words_total: count("SELECT COUNT(*) FROM mimimi.words"),
      words_with_images:
        count("SELECT COUNT(*) FROM mimimi.words WHERE COALESCE(image_url, '') <> ''"),
      words_with_keywords: count("SELECT COUNT(DISTINCT word_id) FROM mimimi.keywords"),
      words_with_both:
        count("""
        SELECT COUNT(DISTINCT w.id) FROM mimimi.words w
        JOIN mimimi.keywords k ON k.word_id = w.id
        WHERE COALESCE(w.image_url, '') <> ''
        """),
      keywords_total: count("SELECT COUNT(*) FROM mimimi.keywords"),
      playable_languages:
        count("SELECT COUNT(*) FROM mimimi.playable_languages WHERE words_with_image_min1_kw > 0")
    }

    assign(socket, :stats, stats)
  end

  defp check_connection do
    Repo.query!("SELECT 1")
    :connected
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp count(sql) do
    %{rows: [[count]]} = Repo.query!(sql)
    {:ok, count}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen px-4 py-12 bg-gradient-to-b from-indigo-50 to-white dark:from-gray-950 dark:to-gray-900">
      <div class="w-full max-w-4xl mx-auto">
        <.page_header />

        <.system_info_card system_info={@system_info} />

        <%= if @loading do %>
          <.loading_card />
        <% else %>
          <.connection_status_card status={@stats.connection_status} />

          <.database_stats_card stats={@stats} />
        <% end %>
      </div>
    </div>
    """
  end

  defp page_header(assigns) do
    ~H"""
    <div class="text-center mb-10">
      <h1 class="text-4xl font-bold text-gray-900 dark:text-white mb-2">
        ourwords Debug
      </h1>
      <p class="text-gray-500 dark:text-gray-400 text-sm">
        Delivery schema connection and view statistics
      </p>
    </div>
    """
  end

  defp system_info_card(assigns) do
    ~H"""
    <.glass_card class="p-8 mb-6">
      <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
        System Information
      </h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <.info_stat
          icon="💧"
          label="Elixir"
          value={@system_info.elixir_version}
          gradient="from-purple-500 to-pink-500"
        />
        <.info_stat
          icon="📡"
          label="Erlang/OTP"
          value={@system_info.erlang_version}
          gradient="from-red-500 to-pink-500"
        />
        <.info_stat
          icon="🔥"
          label="Phoenix"
          value={@system_info.phoenix_version}
          gradient="from-orange-500 to-red-500"
        />
        <.info_stat
          icon="📦"
          label="App Version"
          value={@system_info.app_version}
          gradient="from-green-500 to-emerald-500"
        />
        <.info_stat
          icon="⏰"
          label="Build Time"
          value={@system_info.deployment_timestamp}
          gradient="from-blue-500 to-cyan-500"
        />
      </div>
    </.glass_card>
    """
  end

  defp info_stat(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-4 bg-white dark:bg-gray-900 border-2 border-gray-200 dark:border-gray-700 rounded-2xl">
      <.gradient_icon_badge icon={@icon} gradient={@gradient} size="sm" class="mb-0" />
      <div>
        <p class="text-xs text-gray-500 dark:text-gray-400 font-semibold uppercase">{@label}</p>
        <p class="text-lg font-bold text-gray-900 dark:text-white">{@value}</p>
      </div>
    </div>
    """
  end

  defp loading_card(assigns) do
    ~H"""
    <.glass_card class="p-8">
      <div class="text-center py-8">
        <div class="text-6xl mb-4 opacity-50">⏳</div>
        <p class="text-gray-600 dark:text-gray-400">Lade Statistiken...</p>
      </div>
    </.glass_card>
    """
  end

  defp connection_status_card(assigns) do
    ~H"""
    <.glass_card class="p-8 mb-6">
      <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-4">
        Connection Status
      </h2>
      <div class="flex items-center gap-3">
        <%= if @status == :connected do %>
          <.gradient_icon_badge
            icon="✓"
            gradient="from-green-500 to-emerald-500"
            size="sm"
            class="mb-0"
          />
          <div>
            <p class="text-lg font-semibold text-gray-900 dark:text-white">Connected</p>
            <p class="text-sm text-gray-600 dark:text-gray-400">Delivery schema reachable</p>
          </div>
        <% else %>
          <.gradient_icon_badge
            icon="✗"
            gradient="from-red-500 to-orange-500"
            size="sm"
            class="mb-0"
          />
          <div>
            <p class="text-lg font-semibold text-gray-900 dark:text-white">Error</p>
            <p class="text-sm text-red-600 dark:text-red-400 font-mono">{elem(@status, 1)}</p>
          </div>
        <% end %>
      </div>
    </.glass_card>
    """
  end

  defp database_stats_card(assigns) do
    ~H"""
    <.glass_card class="p-8 mb-6">
      <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-6">
        Delivery Views
      </h2>

      <div class="space-y-4">
        <.stat_row
          label="Words (Total)"
          value={@stats.words_total}
          icon="📝"
          gradient="from-purple-500 to-pink-500"
        />
        <.stat_row
          label="Words with Images"
          value={@stats.words_with_images}
          icon="🖼️"
          gradient="from-blue-500 to-cyan-500"
        />
        <.stat_row
          label="Words with Keywords"
          value={@stats.words_with_keywords}
          icon="🏷️"
          gradient="from-green-500 to-emerald-500"
        />
        <.stat_row
          label="Words with Keywords & Images"
          value={@stats.words_with_both}
          icon="✨"
          gradient="from-yellow-500 to-orange-500"
        />
        <.stat_row
          label="Keywords (Total)"
          value={@stats.keywords_total}
          icon="🔗"
          gradient="from-indigo-500 to-purple-500"
        />
        <.stat_row
          label="Playable Languages"
          value={@stats.playable_languages}
          icon="🌍"
          gradient="from-pink-500 to-rose-500"
        />
      </div>
    </.glass_card>
    """
  end

  defp stat_row(assigns) do
    ~H"""
    <div class="relative group overflow-hidden rounded-2xl">
      <div class={"absolute inset-0 bg-gradient-to-r #{@gradient} opacity-0 group-hover:opacity-10 transition-opacity duration-300"}>
      </div>
      <div class="relative flex items-center justify-between p-4 bg-white dark:bg-gray-900 border-2 border-gray-200 dark:border-gray-700 rounded-2xl transition-all duration-200">
        <div class="flex items-center gap-3">
          <.gradient_icon_badge icon={@icon} gradient={@gradient} size="sm" class="mb-0" />
          <span class="font-semibold text-gray-900 dark:text-white">{@label}</span>
        </div>
        <div class="text-right">
          <%= case @value do %>
            <% {:ok, count} -> %>
              <span class="text-2xl font-bold text-gray-900 dark:text-white">{count}</span>
            <% {:error, message} -> %>
              <span class="text-sm text-red-600 dark:text-red-400 font-mono max-w-xs truncate">
                Error: {message}
              </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
