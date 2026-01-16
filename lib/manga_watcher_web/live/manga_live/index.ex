defmodule MangaWatcherWeb.MangaLive.Index do
  alias MangaWatcher.Accounts
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.UserMangas
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Updater

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    user = Accounts.get_user!(user_id)

    socket
    |> stream(:mangas, UserMangas.filter_mangas(user_id, user.include_tags, user.exclude_tags))
    |> assign(:tags, Series.list_tags())
    |> assign(:user, user)
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
    |> assign(:tags, Series.list_tags())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    manga = Series.get_manga!(id)
    {:ok, _} = UserMangas.delete_manga(manga)

    socket
    |> stream_delete(:mangas, manga)
    |> push_patch(to: ~p"/")
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("rescan", %{"id" => id}, socket) do
    manga = Series.get_manga!(id) |> Updater.update()

    socket
    |> stream_insert(:mangas, manga)
    |> push_patch(to: ~p"/")
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

    user = socket.assigns.user
    include_tags = user.include_tags
    exclude_tags = user.exclude_tags

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

    {:ok, user} = Accounts.update_user_tag_prefs(user, include_tags, exclude_tags)

    socket
    |> assign(:user, user)
    |> stream(:mangas, UserMangas.filter_mangas(user.id, include_tags, exclude_tags), reset: true)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("show_all", _value, socket) do
    current_user_id = socket.assigns.current_user.id

    socket
    |> stream(:mangas, UserMangas.list_mangas(current_user_id), reset: true)
    |> then(&{:noreply, &1})
  end
end
