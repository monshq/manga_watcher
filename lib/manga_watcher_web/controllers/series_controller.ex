defmodule MangaWatcherWeb.SeriesController do
  alias MangaWatcher.Series
  alias MangaWatcher.Utils
  use MangaWatcherWeb, :controller

  require Logger

  def home(conn, _params) do
    mangas = Series.list_mangas()

    conn
    |> assign(:mangas, mangas)
    |> render(:home)
  end

  def new(conn, _params) do
    manga = Series.Manga.create_changeset(%{})

    conn
    |> assign(:manga, manga)
    |> render(:new)
  end

  def create(conn, params) do
    case Series.create_manga(Utils.atomize_keys(params["manga"])) do
      {:ok, manga} ->
        conn
        |> put_flash(:info, "Successfully created #{manga.name}")
        |> redirect(to: ~p"/")

      {:error, manga} ->
        Logger.error("could not save manga: #{inspect(manga.errors)}")

        conn
        |> assign(:manga, manga)
        |> render(:new)
    end
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
    Series.refresh_all_manga()
    mangas = Series.list_mangas()

    conn
    |> assign(:mangas, mangas)
    |> render(:home)
  end
end
