defmodule MangaWatcherWeb.MangaLive.Index do
  alias Phoenix.LiveView.AsyncResult
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Updater

  require Logger

  @default_exclude_tags ["nsfw", "slow-burner"]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:mangas, Series.filter_mangas([], @default_exclude_tags))
    |> assign(:tags, Series.list_tags())
    |> assign(:include_tags, [])
    |> assign(:exclude_tags, @default_exclude_tags)
    |> assign(:refresh_state, AsyncResult.ok(:ok))
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Manga")
    |> assign(:manga, Series.get_manga!(id))
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
  def handle_info({MangaWatcherWeb.MangaLive.FormComponent, {:saved, _manga}}, socket) do
    socket
    |> assign_mangas_with_current_filter()
    |> assign(:tags, Series.list_tags())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    manga = Series.get_manga!(id)
    {:ok, _} = Series.delete_manga(manga)

    socket
    |> assign_mangas_with_current_filter()
    |> push_patch(to: ~p/\//)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("rescan", %{"id" => id}, socket) do
    Series.get_manga!(id) |> Updater.update()

    socket
    |> assign_mangas_with_current_filter()
    |> push_patch(to: ~p/\//)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("refresh_all_manga", _value, socket) do
    include_tags = socket.assigns.include_tags
    exclude_tags = socket.assigns.exclude_tags

    socket
    |> start_async(:refresh_all_manga, fn ->
      Series.refresh_all_manga()
      Series.filter_mangas(include_tags, exclude_tags)
    end)
    |> assign(:refresh_state, AsyncResult.loading())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("filter", value, socket) do
    tag = value["name"]

    next_state_map = %{
      "plus" => "minus",
      "minus" => "neutral",
      "neutral" => "plus"
    }

    next_state = next_state_map[value["state"]]

    include_tags = socket.assigns.include_tags
    exclude_tags = socket.assigns.exclude_tags

    include_tags =
      case next_state do
        "plus" ->
          [tag | include_tags]

        "minus" ->
          include_tags |> Enum.reject(fn t -> t == tag end)

        "neutral" ->
          include_tags
      end

    exclude_tags =
      case next_state do
        "minus" ->
          [tag | exclude_tags]

        "neutral" ->
          exclude_tags |> Enum.reject(fn t -> t == tag end)

        "plus" ->
          exclude_tags
      end

    socket
    |> assign(:include_tags, include_tags)
    |> assign(:exclude_tags, exclude_tags)
    |> assign_mangas_with_current_filter()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("show_all", _value, socket) do
    socket
    |> assign(:mangas, Series.list_mangas())
    |> assign(:exclude_tags, [])
    |> assign(:include_tags, [])
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_async(:refresh_all_manga, {:ok, result}, socket) do
    socket
    |> assign(:mangas, result)
    |> assign(:refresh_state, AsyncResult.ok(:ok))
    |> then(&{:noreply, &1})
  end

  def assign_mangas_with_current_filter(socket) do
    assign(
      socket,
      :mangas,
      Series.filter_mangas(socket.assigns.include_tags, socket.assigns.exclude_tags)
    )
  end
end
