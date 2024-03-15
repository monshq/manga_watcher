defmodule MangaWatcher.Manga.Downloader do
  @spec download(String.t()) :: {:ok, binary} | {:error, atom}
  def download(url) do
    {:ok, Req.get!(url, retry: false, http_errors: :raise).body}
  rescue
    e -> {:error, e}
  end
end
