defmodule MangaWatcher.Fake.Downloader do
  def download(url, _referer \\ "") do
    if url do
      html = File.read!("test/support/fixtures/website_pages/asuratoon.html")
      {:ok, html}
    else
      {:error, "url empty"}
    end
  end
end
