defmodule MangaWatcher.Manga.Downloader do
  @spec download(String.t(), String.t()) :: {:ok, binary} | {:error, atom}
  def download(url, referer \\ "") do
    tesla_client =
      Tesla.client([
        Tesla.Middleware.FollowRedirects,
        {Tesla.Middleware.Headers, [{"Referer", referer}]}
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
