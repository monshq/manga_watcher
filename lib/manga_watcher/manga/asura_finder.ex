defmodule MangaWatcher.Manga.AsuraFinder do
  alias MangaWatcher.Series
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Downloader
  alias MangaWatcher.Utils

  require Logger

  def update_urls() do
    Enum.each(Series.broken_asura_mangas(), fn m ->
      update_url(m)
      Process.sleep(1000)
    end)
  end

  def update_url(%Manga{name: name} = m) do
    word =
      name
      |> String.split(~r/\W/)
      |> Enum.filter(&String.valid?/1)
      |> Enum.max_by(&String.length/1)

    Logger.debug("searching #{name} by word #{word}")

    with {:ok, html} <- Downloader.download("https://asuratoon.com/?s=#{word}"),
         {:ok, url} <- extract_new_url(html, name) do
      if m.url == Utils.normalize_url(url) do
        Logger.info("not updating url for #{name} since it's unchanged")
      else
        Logger.info("updating url for #{name} from #{m.url} to #{url}")
        Series.update_manga(m, %{url: url})
      end
    end
  end

  def extract_new_url(page, name) do
    {:ok, doc} = Floki.parse_document(page)

    urls = Floki.attribute(doc, ".listupd a[title=\"#{name}\"]", "href")

    case urls do
      [] -> {:error, "new url not found"}
      [url] -> {:ok, url}
    end
  end
end
