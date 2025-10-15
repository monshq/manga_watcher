defmodule MangaWatcher.Manga.Updater do
  alias MangaWatcher.Manga.AttrFetcher
  alias MangaWatcher.Series

  require Logger

  @same_host_interval Application.compile_env(:manga_watcher, :same_host_interval)
  @failed_updates_allowed 5

  def batch_update(mangas) do
    Logger.info("starting update of outdated mangas")

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

  def update(manga, attr_fetcher \\ AttrFetcher) do
    case plan_update(manga, attr_fetcher) do
      {:ok, plan} ->
        apply_update_plan(manga, plan)

      {:error, reason} ->
        Logger.error("could not update manga #{manga.name}: #{inspect(reason)}")
        mark_manga_failed(manga)
    end
  end

  def plan_update(manga, attr_fetcher) do
    with {:ok, parsed_attrs} <- manga |> Map.from_struct() |> attr_fetcher.fetch() do
      {:ok,
       %{
         attrs: Map.merge(parsed_attrs, %{failed_updates: 0}),
         mark_stale?: mark_stale?(manga, parsed_attrs),
         remove_broken?: true
       }}
    end
  end

  defp apply_update_plan(manga, %{attrs: attrs, mark_stale?: stale?, remove_broken?: rb}) do
    {:ok, updated} = Series.update_manga(manga, attrs, force: true)

    if rb, do: Series.remove_manga_tag(updated, "broken")

    {:ok, updated} =
      if stale? do
        if !Series.manga_has_tag?(manga, "stale") do
          Logger.warning("manga #{manga.name} is now stale")
        end

        Series.add_manga_tag(updated, "stale")
      else
        Series.remove_manga_tag(updated, "stale")
      end

    updated
  end

  defp mark_manga_failed(manga) do
    {:ok, errored} = Series.update_manga(manga, %{failed_updates: manga.failed_updates + 1})

    if errored.failed_updates > @failed_updates_allowed do
      Logger.warning("manga #{manga.name} is now broken")
      Series.add_manga_tag(errored, "broken")
    end

    errored
  end

  defp mark_stale?(manga, attrs) do
    if manga.last_chapter == attrs[:last_chapter] do
      not_updated_days =
        DateTime.diff(
          DateTime.utc_now(),
          DateTime.from_naive!(manga.last_chapter_updated_at, "Etc/UTC"),
          :day
        )

      Logger.warning("manga #{manga.name} has not been updated for #{not_updated_days}")

      not_updated_days > 30
    else
      false
    end
  end
end
