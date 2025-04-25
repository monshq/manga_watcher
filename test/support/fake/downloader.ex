defmodule MangaWatcher.Fake.Downloader do
  @spec download(String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def download(url, _referer \\ "") when is_binary(url) do
    {:ok, File.read!("test/support/fixtures/website_pages/asuratoon.html")}
  end
end
