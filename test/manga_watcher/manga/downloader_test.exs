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

  describe "fetch/2" do
    test "returns the response for any status", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> put_resp_header("cf-mitigated", "challenge")
        |> send_resp(403, "Just a moment...")
      end)

      url = "http://localhost:#{bypass.port}/manga"

      assert {:ok, %{status: 403, url: ^url, body: "Just a moment...", headers: headers}} =
               Downloader.fetch(url)

      assert headers["cf-mitigated"] == ["challenge"]
    end

    test "returns the url after redirects and sends the referer", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/old", fn conn ->
        conn |> put_resp_header("location", "/new") |> send_resp(301, "")
      end)

      Bypass.expect(bypass, "GET", "/new", fn conn ->
        assert get_req_header(conn, "referer") == ["https://example.com"]
        send_resp(conn, 200, "moved")
      end)

      assert {:ok, %{status: 200, url: url, body: "moved"}} =
               Downloader.fetch("http://localhost:#{bypass.port}/old",
                 referer: "https://example.com"
               )

      assert url == "http://localhost:#{bypass.port}/new"
    end

    test "with guard rejects private addresses without sending a request", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %MangaWatcher.Manga.UrlGuard.BlockedError{}} =
               Downloader.fetch("http://localhost:#{bypass.port}/", guard: true)
    end
  end
end
