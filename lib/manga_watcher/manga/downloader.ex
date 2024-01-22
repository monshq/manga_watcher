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
        if Integer.to_string(request.status) =~ ~r/2\d\d/ do
          {:ok, request.body}
        else
          {:error, "wrong response code: #{request.status}"}
        end

      error ->
        error
    end
  end
end
