defmodule MangaWatcher.Manga.DownloaderTest do
  use ExUnit.Case, async: true
  import Plug.Conn

  alias MangaWatcher.Manga.Downloader

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "returns {:ok, body} on 200 response without referer", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert get_req_header(conn, "referer") == [""]
      assert get_req_header(conn, "user-agent") == ["MangaWatcher/1.0.0"]

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "fake-body")
    end)

    url = "http://localhost:#{bypass.port}/download"
    assert Downloader.download(url) == {:ok, "fake-body"}
  end

  test "returns {:ok, body} on 200 response with custom referer", %{bypass: bypass} do
    custom_referer = "http://example.com/chap1"

    Bypass.expect(bypass, fn conn ->
      assert get_req_header(conn, "referer") == [custom_referer]
      assert get_req_header(conn, "user-agent") == ["MangaWatcher/1.0.0"]

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "body-with-referer")
    end)

    url = "http://localhost:#{bypass.port}/download"
    assert Downloader.download(url, custom_referer) == {:ok, "body-with-referer"}
  end

  test "returns error tuple on non-200 status", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      send_resp(conn, 404, "not found")
    end)

    url = "http://localhost:#{bypass.port}/missing"
    assert Downloader.download(url) == {:error, "wrong response code: 404"}
  end

  @tag :capture_log
  test "catches exceptions and returns {:error, exception}" do
    assert match?({:error, %_{}}, Downloader.download("http://invalid.invalid"))
  end
end
