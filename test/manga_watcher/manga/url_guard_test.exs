defmodule MangaWatcher.Manga.UrlGuardTest do
  use ExUnit.Case, async: true

  alias MangaWatcher.Manga.UrlGuard

  test "allows public addresses" do
    assert UrlGuard.check("https://93.184.216.34/manga/1") == :ok
    assert UrlGuard.check("http://[2606:2800:220:1::]/manga") == :ok
  end

  test "rejects private, loopback and link-local addresses" do
    for url <- [
          "http://127.0.0.1:4000/",
          "http://localhost:8080/api",
          "http://10.0.0.5/",
          "http://172.20.1.1/",
          "http://192.168.1.10/",
          "http://169.254.169.254/latest/meta-data",
          "http://100.64.0.1/",
          "http://0.0.0.0/",
          "http://[::1]/",
          "http://[fd00::1]/",
          "http://[fe80::1]/",
          "http://[::ffff:192.168.0.1]/"
        ] do
      assert {:error, _} = UrlGuard.check(url), "expected #{url} to be blocked"
    end
  end

  test "rejects urls without http scheme or host" do
    assert {:error, _} = UrlGuard.check("ftp://example.com/file")
    assert {:error, _} = UrlGuard.check("example.com/manga")
    assert {:error, _} = UrlGuard.check("http://")
  end
end
