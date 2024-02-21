defmodule MangaWatcherWeb.MangaLive.Index do
  alias Phoenix.LiveView.AsyncResult
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.Series.Manga

  require Logger

  @default_exclude_tags ["nsfw", "slow-burner"]

  @impl true
  def mount(_params, _session, socket) do
    assigns =
      socket
      |> assign(:mangas, Series.filter_mangas([], @default_exclude_tags))
      |> assign(:tags, Series.list_tags())
      |> assign(:include_tags, [])
      |> assign(:exclude_tags, @default_exclude_tags)
      |> assign(:refresh_state, AsyncResult.ok(:ok))

    {:ok, assigns}
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
    |> assign(:page_title, "Listing Mangas")
    |> assign(:manga, nil)
  end

  @impl true
  def handle_info({MangaWatcherWeb.MangaLive.FormComponent, {:saved, _manga}}, socket) do
    {:noreply,
     socket
     |> assign(:mangas, list_mangas_with_current_filter(socket.assigns))
     |> assign(:tags, Series.list_tags())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    manga = Series.get_manga!(id)
    {:ok, _} = Series.delete_manga(manga)

    socket =
      socket
      |> assign(:mangas, list_mangas_with_current_filter(socket.assigns))
      |> push_patch(to: ~p/\//)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_all_manga", _value, socket) do
    assigns =
      socket
      |> start_async(:refresh_all_manga, fn ->
        Series.refresh_all_manga()
        list_mangas_with_current_filter(socket.assigns)
      end)
      |> assign(:refresh_state, AsyncResult.loading())

    {:noreply, assigns}
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

    socket =
      socket
      |> assign(:mangas, Series.filter_mangas(include_tags, exclude_tags))
      |> assign(:include_tags, include_tags)
      |> assign(:exclude_tags, exclude_tags)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_all", _value, socket) do
    socket =
      socket
      |> assign(:mangas, Series.list_mangas())
      |> assign(:exclude_tags, [])
      |> assign(:include_tags, [])

    {:noreply, socket}
  end

  @impl true
  def handle_async(:refresh_all_manga, {:ok, result}, socket) do
    assigns =
      socket
      |> assign(:mangas, result)
      |> assign(:refresh_state, AsyncResult.ok(:ok))

    {:noreply, assigns}
  end

  def list_mangas_with_current_filter(assigns) do
    Series.filter_mangas(assigns.include_tags, assigns.exclude_tags)
  end
end
