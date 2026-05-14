defmodule MangaWatcher.UtilsTest do
  use ExUnit.Case, async: true

  alias MangaWatcher.Utils

  describe "normalize_url/1" do
    test "strips trailing slash" do
      assert Utils.normalize_url("http://example.com/manga/") == "http://example.com/manga"
    end

    test "keeps URL without trailing slash unchanged" do
      assert Utils.normalize_url("http://example.com/manga") == "http://example.com/manga"
    end

    test "handles URL with no scheme" do
      assert Utils.normalize_url("example.com/manga") == "example.com/manga"
    end

    test "handles root path" do
      assert Utils.normalize_url("http://example.com/") == "http://example.com"
    end

    test "preserves https scheme" do
      assert Utils.normalize_url("https://example.com/manga/") == "https://example.com/manga"
    end
  end

  describe "normalize_host/1" do
    test "extracts host from URL with scheme" do
      assert Utils.normalize_host("http://example.com/manga/123") == "example.com"
    end

    test "extracts host from URL without scheme" do
      assert Utils.normalize_host("example.com") == "example.com"
    end

    test "handles https URLs" do
      assert Utils.normalize_host("https://mangasite.org/chapter/1") == "mangasite.org"
    end

    test "returns nil for nil input" do
      assert Utils.normalize_host(nil) == nil
    end
  end
end
