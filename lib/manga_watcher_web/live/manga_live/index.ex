defmodule MangaWatcherWeb.MangaLive.Index do
  alias Phoenix.LiveView.AsyncResult
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.Series.Manga

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    assigns =
      socket
      |> assign(:mangas, Series.list_mangas())
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
  def handle_info({MangaWatcherWeb.MangaLive.FormComponent, {:saved, manga}}, socket) do
    {:noreply, stream_insert(socket, :mangas, manga)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    manga = Series.get_manga!(id)
    {:ok, _} = Series.delete_manga(manga)

    {:noreply, stream_delete(socket, :mangas, manga)}
  end

  @impl true
  def handle_event("refresh_all_manga", _value, socket) do
    assigns =
      socket
      |> start_async(:refresh_all_manga, fn ->
        Series.refresh_all_manga()
        Series.list_mangas()
      end)
      |> assign(:refresh_state, AsyncResult.loading())

    {:noreply, assigns}
  end

  @impl true
  def handle_async(:refresh_all_manga, {:ok, result}, socket) do
    assigns =
      socket
      |> assign(:mangas, result)
      |> assign(:refresh_state, AsyncResult.ok(:ok))

    {:noreply, assigns}
  end
end
