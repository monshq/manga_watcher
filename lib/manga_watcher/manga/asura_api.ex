defmodule MangaWatcher.Manga.AsuraApi do
  @moduledoc """
  Asura manga pages are behind a Cloudflare challenge, while its json api is
  not, so attrs of asurascans.com mangas are taken from the api instead.
  """

  @host "asurascans.com"
  @api_url "https://api.asurascans.com/api/series/"

  def handles?(url), do: URI.parse(url).host in [@host, "www." <> @host]

  @spec fetch(String.t(), module()) :: {:ok, map()} | {:error, term()}
  def fetch(url, downloader) do
    with {:ok, slug} <- slug(url),
         {:ok, %{"series" => series}} <- get_series(downloader, slug),
         {:ok, %{"data" => chapters}} <- get_json(downloader, @api_url <> slug <> "/chapters") do
      last_chapter =
        chapters
        |> Enum.reject(& &1["is_premium"])
        |> Enum.map(&trunc(&1["number"]))
        |> Enum.max(fn -> nil end)

      if last_chapter do
        {:ok, %{name: series["title"], last_chapter: last_chapter, preview: series["cover"]}}
      else
        {:error, "could not find any free chapters"}
      end
    else
      {:ok, body} -> {:error, "unexpected asura api response: #{inspect(body, limit: 5)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp slug(url) do
    case URI.parse(url).path do
      "/comics/" <> slug when slug != "" -> {:ok, slug |> String.split("/") |> hd()}
      _ -> {:error, "not an asura comic url: #{url}"}
    end
  end

  # slugs without the hash suffix get the same series wrapped in "data"
  defp get_series(downloader, slug) do
    case get_json(downloader, @api_url <> slug) do
      {:ok, %{"data" => %{"series" => _} = series}} -> {:ok, series}
      other -> other
    end
  end

  # Req decodes json bodies itself, other downloaders return the raw body
  defp get_json(downloader, url) do
    case downloader.download(url) do
      {:ok, body} when is_binary(body) -> Jason.decode(body)
      other -> other
    end
  end
end
