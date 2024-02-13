defmodule MangaWatcher.Manga.Updater do
  alias MangaWatcher.Series
  alias MangaWatcher.Manga.PageParser

  require Logger

  @downloader Application.compile_env(:manga_watcher, :page_downloader)

  def batch_update(mangas) do
    Logger.info("starting update of all mangas")

    Enum.each(mangas, &update/1)

    Logger.info("finished updating mangas")
  end

  def update(manga) do
    case manga |> Map.from_struct() |> parse_attrs() do
      {:ok, parsed_attrs} ->
        {:ok, _} = Series.update_manga(manga, Map.merge(parsed_attrs, %{failed_updates: 0}))

      {:error, reason} ->
        Logger.error("could not update manga #{manga.name}: #{reason}")
        {:ok, _} = Series.update_manga(manga, %{failed_updates: manga.failed_updates + 1})
    end
  end

  def parse_attrs(manga_attrs) when is_binary(manga_attrs.url) do
    with {:ok, html_content} <- @downloader.download(manga_attrs.url),
         {:ok, attrs} <- PageParser.parse(html_content) do
      {:ok, Map.merge(manga_attrs, attrs)}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_attrs(_manga_attrs), do: {:error, "url is missing"}
end
