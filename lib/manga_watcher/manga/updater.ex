defmodule MangaWatcher.Manga.Updater do
  alias MangaWatcher.PreviewUploader
  alias MangaWatcher.Series

  require Logger

  @same_host_interval Application.compile_env(:manga_watcher, :same_host_interval)
  @failed_updates_allowed 5

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

  def update(manga, deps \\ default_deps()) do
    case plan_update(manga, deps) do
      {:ok, plan} ->
        apply_update_plan(manga, plan)

      {:error, reason} ->
        Logger.error("could not update manga #{manga.name}: #{reason}")
        mark_manga_failed(manga)
    end
  end

  def plan_update(manga, deps) do
    with {:ok, parsed_attrs} <- manga |> Map.from_struct() |> parse_attrs(deps) do
      {:ok,
       %{
         attrs: Map.merge(parsed_attrs, %{failed_updates: 0}),
         mark_stale?: mark_stale?(manga, parsed_attrs),
         remove_broken?: true
       }}
    end
  end

  defp apply_update_plan(manga, %{attrs: attrs, mark_stale?: stale?, remove_broken?: rb}) do
    {:ok, updated} = Series.update_manga(manga, attrs)

    true = Series.register_manga_scan(updated)

    if rb, do: Series.remove_manga_tag(updated, "broken")

    {:ok, updated} =
      if stale? do
        Series.add_manga_tag(updated, "stale")
      else
        Series.remove_manga_tag(updated, "stale")
      end

    updated
  end

  defp mark_manga_failed(manga) do
    {:ok, errored} =
      Series.update_manga(manga, %{
        failed_updates: manga.failed_updates + 1,
        scanned_at: DateTime.utc_now()
      })

    if errored.failed_updates > @failed_updates_allowed do
      Logger.warning("manga #{manga.name} is now broken")
      Series.add_manga_tag(errored, "broken")
    end

    errored
  end

  defp mark_stale?(manga, attrs) do
    if manga.last_chapter == attrs[:last_chapter] do
      not_updated_days =
        DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(manga.updated_at, "Etc/UTC"), :day)

      not_updated_days > 30
    else
      false
    end
  end

  def parse_attrs(manga_attrs, deps \\ default_deps()) do
    with {:ok, url} <- Map.fetch(manga_attrs, :url),
         {:ok, website} <- Series.get_website_for_url(url),
         {:ok, html_content} <- deps.downloader.download(url),
         {:ok, attrs} <- deps.page_parser.parse(html_content, website),
         Logger.info("found following attrs for manga: #{inspect(attrs)}"),
         {:ok, preview} <-
           store_preview(
             %{
               preview_url: attrs[:preview],
               existing_preview: manga_attrs[:preview],
               manga_name: attrs[:name],
               manga_url: url
             },
             deps
           ) do
      {:ok, manga_attrs |> Map.merge(attrs) |> Map.merge(%{preview: preview})}
    else
      :error ->
        {:error, "url is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_preview(
         %{existing_preview: original_preview} = input,
         deps
       )
       when original_preview != nil do
    if PreviewUploader.exists?(original_preview) do
      {:ok, original_preview}
    else
      store_preview(Map.put(input, :existing_preview, nil), deps)
    end
  end

  defp store_preview(%{preview_url: nil}, _deps), do: {:ok, nil}

  defp store_preview(
         %{
           preview_url: new_preview,
           manga_name: name,
           manga_url: url
         },
         %{downloader: downloader}
       ) do
    Logger.debug("downloading preview from #{new_preview}")

    case downloader.download(new_preview, get_referer(url)) do
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

  defp default_deps do
    %{
      downloader: Application.get_env(:manga_watcher, :page_downloader),
      page_parser: MangaWatcher.Manga.PageParser
    }
  end
end
