defmodule MangaWatcher.Fake.Downloader do
  def download(_url, _referer) do
    html = File.read!("test/support/fixtures/website_pages/asuratoon.html")
    {:ok, html}
  end
end
