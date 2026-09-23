defmodule MangaWatcher.Fake.Downloader do
  @spec download(String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def download(url, _referer \\ "") when is_binary(url) do
    {:ok, File.read!("test/support/fixtures/website_pages/asuratoon.html")}
  end

  def fetch(url, _opts \\ []) when is_binary(url) do
    if Path.extname(URI.parse(url).path || "") in [".png", ".jpg", ".jpeg", ".webp"] do
      {:ok, %{status: 200, url: url, headers: %{"content-type" => ["image/png"]}, body: "img"}}
    else
      {:ok, body} = download(url)
      {:ok, %{status: 200, url: url, headers: %{"content-type" => ["text/html"]}, body: body}}
    end
  end
end
