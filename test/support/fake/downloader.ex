defmodule MangaWatcher.Fake.Downloader do
  @image_exts [".png", ".jpg", ".jpeg", ".webp"]

  @spec download(String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def download(url, _referer \\ "") when is_binary(url) do
    if image?(url) do
      {:ok, File.read!("test/support/fixtures/preview.png")}
    else
      {:ok, File.read!("test/support/fixtures/website_pages/asuratoon.html")}
    end
  end

  def fetch(url, _opts \\ []) when is_binary(url) do
    {:ok, body} = download(url)
    content_type = if image?(url), do: "image/png", else: "text/html"
    {:ok, %{status: 200, url: url, headers: %{"content-type" => [content_type]}, body: body}}
  end

  defp image?(url), do: Path.extname(URI.parse(url).path || "") in @image_exts
end
