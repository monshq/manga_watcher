defmodule MangaWatcher.Tasks.GenerateThumbnails do
  @moduledoc """
  Generates thumbnails for stored previews that do not have one yet,
  e.g. previews uploaded before the thumb version was added.

  Run this against a running release with:

      bin/manga_watcher rpc 'MangaWatcher.Tasks.GenerateThumbnails.run()'
  """

  alias MangaWatcher.PreviewUploader
  alias MangaWatcher.Series

  require Logger

  def run do
    previews =
      Series.list_mangas_with_preview()
      |> Enum.map(& &1.preview)
      |> Enum.uniq()
      |> Enum.reject(&PreviewUploader.exists?(&1, :thumb))

    Logger.info("generating thumbnails for #{length(previews)} previews")

    results = Enum.map(previews, &generate/1)
    failed = Enum.count(results, &match?({:error, _}, &1))

    Logger.info("generated #{length(previews) - failed} thumbnails, #{failed} failed")
  end

  # re-stores the original as well, waffle has no way to store a single version
  defp generate(preview) do
    with {:ok, binary} <- PreviewUploader.read(preview),
         {:ok, _} <- PreviewUploader.store(%{filename: preview, binary: binary}) do
      :ok
    else
      error ->
        Logger.error("could not generate thumbnail for #{preview}: #{inspect(error)}")
        {:error, error}
    end
  end
end
