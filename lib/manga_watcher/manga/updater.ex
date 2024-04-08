defmodule MangaWatcher.Manga.Updater do
  alias MangaWatcher.PreviewUploader
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
         {:ok, website} <- Series.get_website_for_url(url),
         {:ok, html_content} <- @downloader.download(url),
         {:ok, attrs} <- PageParser.parse(html_content, website),
         :ok <- Logger.info("found following attrs for manga: #{inspect(attrs)}"),
         {:ok, preview} <-
           store_preview(attrs[:preview], manga_attrs[:preview], attrs[:name], url) do
      {:ok, manga_attrs |> Map.merge(attrs) |> Map.merge(%{preview: preview})}
    else
      :error ->
        {:error, "url is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_preview(nil, _, _, _), do: {:ok, nil}

  defp store_preview(new_preview, nil, name, url) do
    Logger.debug("downloading preview from #{new_preview}")

    case @downloader.download(new_preview, get_referer(url)) do
      {:ok, preview_bin} ->
        PreviewUploader.store(%{
          filename: preview_filename(name, new_preview),
          binary: preview_bin
        })

      {:error, error} ->
        Logger.error("could not download preview for #{name}: #{inspect(error)}")
        {:ok, nil}
    end
  end

  defp store_preview(new_preview, original_preview, name, url) do
    if PreviewUploader.exists?(original_preview) do
      {:ok, original_preview}
    else
      store_preview(new_preview, nil, name, url)
    end
  end

  defp preview_filename(manga_name, url) do
    name =
      manga_name
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
      |> String.replace(~r/[^A-z]+/, "")

    ext =
      url |> Path.extname() |> String.downcase()

    name <> ext
  end

  defp get_referer(url) do
    "https://" <> URI.parse(url).host
  rescue
    _ -> ""
  end
end
