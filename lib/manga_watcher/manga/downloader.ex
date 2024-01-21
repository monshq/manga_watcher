defmodule MangaWatcher.Manga.Downloader do
  @spec download(String.t()) :: {:ok, binary} | {:error, atom}
  def download(url) do
    tesla_client =
      Tesla.client([
        Tesla.Middleware.FollowRedirects
        # Tesla.Middleware.Logger
      ])

    case Tesla.get(tesla_client, url) do
      {:ok, request} ->
        {:ok, request.body}

      error ->
        error
    end
  end
end
