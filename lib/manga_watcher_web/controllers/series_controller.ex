defmodule MangaWatcherWeb.SeriesController do
  alias MangaWatcher.Series
  use MangaWatcherWeb, :controller

  def home(conn, _params) do
    mangas = Series.list_mangas()

    conn
    |> assign(:mangas, mangas)
    |> render(:home)
  end

  def new(conn, _params) do
    manga = %Series.Manga{}

    conn
    |> assign(:manga, manga)
    |> render(:new)
  end

  def read(conn, params) do
    manga = Series.get_manga!(params["id"])
    {:ok, manga} = Series.update_manga(manga, %{last_read_chapter: manga.last_chapter})

    conn
    |> assign(:m, manga)
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:manga)
  end

  def update_all(conn, _params) do
    spawn(fn -> Series.refresh_all_manga() end)

    conn
    |> render(:processing_button)
  end
end
