defmodule MangaWatcher.Manga.AttrFetcherTest do
  use MangaWatcher.DataCase, async: true

  import Mox
  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.Manga.AttrFetcher
  alias MangaWatcher.PreviewUploader

  setup do
    website_fixture()
    verify_on_exit!()
  end

  describe "fetch/2" do
    test "successfully finds website, parses page, and stores preview" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1"
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>manga page</html>"}
      end)
      |> expect(:download, fn "https://cdn.mangasource.com/preview.jpg", _headers ->
        {:ok, "binary_preview"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok,
         %{name: "My Manga", last_chapter: 5, preview: "https://cdn.mangasource.com/preview.jpg"}}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.name == "My Manga"
      assert attrs.last_chapter == 5
      assert String.ends_with?(attrs.preview, ".jpg")
    end

    @tag :capture_log
    test "returns error if website cannot be found" do
      manga_attrs = %{
        url: "https://unknownsite.com/manga/1"
      }

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:error, _reason} = AttrFetcher.fetch(manga_attrs, deps)
    end

    test "returns error if downloader fails" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1"
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:error, :timeout}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:error, :timeout} = AttrFetcher.fetch(manga_attrs, deps)
    end

    test "returns error if page parser fails" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1"
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>broken html</html>"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:error, :parse_error}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:error, :parse_error} = AttrFetcher.fetch(manga_attrs, deps)
    end

    test "does not redownload preview if existing preview already exists" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1",
        preview: "existing_preview.jpg"
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>ok</html>"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok,
         %{name: "My Manga", last_chapter: 5, preview: "https://cdn.mangasource.com/preview.jpg"}}
      end)

      PreviewUploader.store(%{
        filename: "existing_preview.jpg",
        binary: "dummy"
      })

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.preview == "existing_preview.jpg"
    end
  end
end
