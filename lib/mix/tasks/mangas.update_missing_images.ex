defmodule Mix.Tasks.Mangas.UpdateMissingImages do
  use Mix.Task

  @moduledoc """
  Updates every manga whose preview image is missing.
  """
  @shortdoc "Updates every manga with a missing preview image"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    MangaWatcher.Tasks.UpdateMissingImages.run()
  end
end
