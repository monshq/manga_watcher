defmodule MangaWatcher.Manga.Downloader do
  @spec download(String.t(), String.t()) :: {:ok, binary} | {:error, atom}
  def download(url, referer \\ "") do
    case Req.get!(url,
           headers: [{"Referer", referer}, {"User-Agent", "MangaWatcher/1.0.0"}],
           redirect_trusted: true
         ) do
      %Req.Response{status: 200, body: body} ->
        {:ok, body}

      %Req.Response{status: status} ->
        {:error, "wrong response code: #{status}"}
    end
  rescue
    e -> {:error, e}
  end
end
