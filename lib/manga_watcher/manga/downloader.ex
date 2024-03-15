defmodule MangaWatcher.Manga.Downloader do
  @spec download(String.t()) :: {:ok, binary} | {:error, atom}
  def download(url) do
    case Req.get!(url) do
      %Req.Response{status: 200, body: body} ->
        {:ok, body}

      %Req.Response{status: status} ->
        {:error, "wrong response code: #{status}"}
    end
  rescue
    e -> {:error, e}
  end
end
