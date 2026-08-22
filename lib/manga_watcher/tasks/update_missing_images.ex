defmodule MangaWatcher.Tasks.UpdateMissingImages do
  @moduledoc """
  Updates every manga that does not have a stored preview image.

  Run this against a running release with:

      bin/manga_watcher rpc 'MangaWatcher.Tasks.UpdateMissingImages.run()'
  """

  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.Series

  require Logger

  def run do
    mangas = Series.list_mangas_with_missing_preview()

    Logger.info("found #{length(mangas)} mangas with missing images")
    Updater.batch_update(mangas)
  end
end
