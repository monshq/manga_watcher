defmodule MangaWatcherWeb.MangaLive.Index do
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.UserMangas
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.MangaFilter
  alias MangaWatcherWeb.FilterPrefs

  # tags that mirror a reading state, covered by the `is:` predicates
  @state_tags ["broken", "dormant"]

  @impl true
  def mount(_params, session, socket) do
    base = socket |> FilterPrefs.from_socket(session) |> FilterPrefs.decode()

    socket
    |> assign(:tags, list_tags())
    |> assign(base: base, base_input: base, base_error: nil)
    |> assign(query: nil, query_input: "", query_error: nil, show_all: false)
    |> assign(editing: false)
    |> then(&{:ok, &1})
  end

  defp list_tags do
    Series.list_tags() |> Enum.reject(&(&1.name in @state_tags)) |> Enum.sort_by(& &1.name)
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket
    |> apply_filter(params)
    |> apply_action(socket.assigns.live_action, params)
    |> then(&{:noreply, &1})
  end

  # the modal routes don't carry the filter, so it only changes on the index
  # (or when a modal route is the first thing opened)
  defp apply_filter(socket, params) do
    query = String.trim(params["q"] || "")
    show_all = params["all"] == "1"
    %{query: current_query, show_all: current_show_all} = socket.assigns

    cond do
      is_nil(current_query) ->
        load_mangas(socket, query, show_all)

      socket.assigns.live_action == :index and
          {query, show_all} != {current_query, current_show_all} ->
        load_mangas(socket, query, show_all)

      true ->
        socket
    end
  end

  defp load_mangas(socket, query, show_all) do
    {query_filter, query_error} = parse(query)
    {base_filter, base_error} = parse(socket.assigns.base)
    applied_base = if show_all, do: MangaFilter.empty(), else: base_filter
    filter = MangaFilter.merge(applied_base, query_filter)

    socket
    |> assign(query: query, query_input: query, query_error: query_error, show_all: show_all)
    |> assign(base_input: socket.assigns.base, base_error: base_error)
    |> assign(query_filter: query_filter, base_filter: base_filter)
    |> assign(:base_summary, base_summary(applied_base, query_filter))
    |> stream(:mangas, UserMangas.filter_mangas(socket.assigns.current_user.id, filter),
      reset: true
    )
  end

  defp base_summary(base_filter, query_filter) do
    base_filter |> MangaFilter.without_overridden(query_filter) |> MangaFilter.to_string()
  end

  # a broken filter (hand-edited URL or cookie) filters nothing
  defp parse(query) do
    case MangaFilter.parse(query) do
      {:ok, filter} -> {filter, nil}
      {:error, message} -> {MangaFilter.empty(), message}
    end
  end

  defp index_path(assigns, overrides \\ []) do
    query = Keyword.get(overrides, :query, assigns.query)
    show_all = Keyword.get(overrides, :show_all, assigns.show_all)

    params =
      if(query in [nil, ""], do: [], else: [q: query]) ++ if(show_all, do: [all: 1], else: [])

    ~p"/mangas?#{params}"
  end

  defp unknown_tags(tags, filters) do
    known = MapSet.new(tags, &String.downcase(&1.name))
    filters |> Enum.flat_map(&MangaFilter.tags/1) |> Enum.uniq() |> Enum.reject(&(&1 in known))
  end

  defp tag_classes(:include, :query), do: "bg-green-200 text-green-800"
  defp tag_classes(:exclude, :query), do: "bg-red-200 text-red-800"

  defp tag_classes(:include, :base),
    do: "ring-1 ring-inset ring-green-500 text-green-700 dark:text-green-400"

  defp tag_classes(:exclude, :base),
    do: "ring-1 ring-inset ring-red-400 text-red-700 dark:text-red-400"

  defp tag_classes(nil, _), do: "bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  attr :name, :string, required: true
  attr :query_filter, :any, required: true
  attr :base_filter, :any, required: true
  attr :show_all, :boolean, required: true

  defp tag_chip(assigns) do
    query_state = MangaFilter.tag_state(assigns.query_filter, assigns.name)

    base_state =
      if assigns.show_all, do: nil, else: MangaFilter.tag_state(assigns.base_filter, assigns.name)

    {state, source} = if query_state, do: {query_state, :query}, else: {base_state, :base}
    assigns = assign(assigns, state: state, source: source)

    ~H"""
    <button
      type="button"
      phx-click="toggle_tag"
      phx-value-name={@name}
      data-state={@state}
      data-source={@state && @source}
      title={@state && @source == :base && "from the default filter"}
      class={[
        "text-xs inline-flex items-center font-bold uppercase px-3 py-1 rounded-full",
        tag_classes(@state, @source)
      ]}
    >
      <.icon :if={@state == :include} name="hero-plus" class="mr-1 w-3 h-3" />
      <.icon :if={@state == :exclude} name="hero-minus" class="mr-1 w-3 h-3" />
      {@name}
    </button>
    """
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:page_title, "Edit Manga")
    |> assign(:manga, UserMangas.get_manga!(user_id, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Manga")
    |> assign(:manga, %Manga{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manga Watcher")
    |> assign(:manga, nil)
  end

  @impl true
  def handle_info({MangaWatcherWeb.MangaLive.FormComponent, {:saved, manga}}, socket) do
    socket
    |> stream_insert(:mangas, manga)
    |> assign(:tags, list_tags())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    manga = UserMangas.get_manga!(socket.assigns.current_user.id, id)
    :ok = UserMangas.unfollow_manga(socket.assigns.current_user.id, manga.id)

    socket
    |> stream_delete(:mangas, manga)
    |> push_patch(to: index_path(socket.assigns))
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("rescan", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    %Manga{id: id} = UserMangas.get_manga!(user_id, id)

    # the updater needs every follower's record to tell whether the manga is dormant
    Series.get_manga!(id) |> Updater.update()
    manga = UserMangas.get_manga!(user_id, id)

    socket
    |> stream_insert(:mangas, manga)
    |> push_patch(to: index_path(socket.assigns))
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("toggle_editor", _value, socket) do
    {:noreply, update(socket, :editing, &(not &1))}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    query = String.trim(query)

    case MangaFilter.parse(query) do
      {:ok, _filter} ->
        socket
        |> assign(query_input: query, query_error: nil)
        |> push_patch(to: index_path(socket.assigns, query: query))
        |> then(&{:noreply, &1})

      {:error, message} ->
        {:noreply, assign(socket, query_input: query, query_error: message)}
    end
  end

  @impl true
  def handle_event("toggle_tag", %{"name" => name}, socket) do
    query =
      socket.assigns.query_filter |> MangaFilter.toggle_tag(name) |> MangaFilter.to_string()

    {:noreply, push_patch(socket, to: index_path(socket.assigns, query: query))}
  end

  @impl true
  def handle_event("save_base", %{"base" => base}, socket) do
    base = String.trim(base)

    with :ok <- check_length(base),
         {:ok, _filter} <- MangaFilter.parse(base) do
      socket
      |> assign(base: base)
      |> push_event("filter_base", %{value: base})
      |> load_mangas(socket.assigns.query, socket.assigns.show_all)
      |> then(&{:noreply, &1})
    else
      {:error, message} ->
        {:noreply, assign(socket, base_input: base, base_error: message)}
    end
  end

  defp check_length(base) do
    if String.length(base) <= FilterPrefs.max_length(),
      do: :ok,
      else: {:error, "the default filter is too long"}
  end
end
