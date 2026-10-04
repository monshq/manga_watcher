defmodule MangaWatcher.Tasks.UpdateMissingImages do
  @moduledoc """
  Updates every manga that does not have a stored preview image, including
  mangas whose preview points to an object that no longer exists in storage.

  Run this against a running release with:

      bin/manga_watcher rpc 'MangaWatcher.Tasks.UpdateMissingImages.run()'
  """

  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.PreviewUploader
  alias MangaWatcher.Series

  require Logger

  def run do
    missing_preview = Series.list_mangas_with_missing_preview()

    dead_preview =
      Series.list_mangas_with_preview()
      |> Enum.filter(&missing?(&1.preview))

    mangas = missing_preview ++ dead_preview

    Logger.info(
      "found #{length(mangas)} mangas with missing images " <>
        "(#{length(missing_preview)} without preview, #{length(dead_preview)} with dead preview)"
    )

    Updater.batch_update(mangas)
  end

  # storage errors are skipped, otherwise an unreachable storage marks every preview as dead
  defp missing?(preview) do
    case PreviewUploader.stored(preview) do
      {:ok, stored?} ->
        not stored?

      {:error, error} ->
        Logger.error("could not check preview #{preview}: #{inspect(error)}")
        false
    end
  end
end
