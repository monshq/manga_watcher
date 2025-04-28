defmodule MangaWatcher.Manga.Creator do
  alias MangaWatcher.Manga.AttrFetcher
  alias MangaWatcher.Series
  alias MangaWatcher.UserMangas
  alias MangaWatcher.Repo
  alias Ecto.Multi

  import Ecto.Query, warn: false

  require Logger

  def add_for_user(user_id, attrs, attr_fetcher \\ AttrFetcher) do
    Multi.new()
    |> Multi.run(:manga, fn _repo, _changes ->
      if manga = Series.get_manga(%{url: attrs[:url]}) do
        {:ok, manga}
      else
        attrs
        |> fetch_manga_attrs(attr_fetcher)
        |> Series.create_manga()
      end
    end)
    |> Multi.run(:user_manga, fn _repo, %{manga: manga} ->
      UserMangas.create_user_manga(%{
        manga_id: manga.id,
        user_id: user_id,
        last_read_chapter: manga.last_chapter
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{manga: manga, user_manga: user_manga}} ->
        {:ok, %{user_manga | manga: Series.get_manga!(manga.id)}}

      {:error, _step, reason, _changes_so_far} ->
        {:error, reason}
    end
  end

  defp fetch_manga_attrs(attrs, attr_fetcher) do
    case attr_fetcher.fetch(attrs) do
      {:ok, parsed_attrs} ->
        parsed_attrs

      {:error, e} ->
        Logger.error("fetching manga attrs failed: #{inspect(e)}")
        attrs
    end
  end
end
