defmodule MangaWatcher.Manga.Updater do
  alias MangaWatcher.Series
  alias MangaWatcher.Manga.PageParser

  require Logger

  @downloader Application.compile_env(:manga_watcher, :page_downloader)
  @same_host_interval Application.compile_env(:manga_watcher, :same_host_interval)

  def batch_update(mangas) do
    Logger.info("starting update of all mangas")

    mangas
    |> Enum.group_by(&URI.parse(&1.url).host)
    |> Task.async_stream(&update_group/1,
      ordered: false,
      timeout: 180_000,
      max_concurrency: 10
    )
    |> Stream.run()

    Logger.info("finished updating mangas")
  end

  defp update_group({host, mangas}) do
    Logger.info("found #{length(mangas)} mangas for host #{host}")

    mangas
    |> Enum.each(fn m ->
      update(m)
      Process.sleep(@same_host_interval)
    end)
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

  def parse_attrs(manga_attrs) do
    with {:ok, url} <- Map.fetch(manga_attrs, :url),
         {:ok, html_content} <- @downloader.download(url),
         {:ok, attrs} <- PageParser.parse(html_content) do
      {:ok, Map.merge(manga_attrs, attrs)}
    else
      :error ->
        {:error, "url is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
