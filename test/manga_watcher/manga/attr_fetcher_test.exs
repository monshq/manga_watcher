defmodule MangaWatcher.Manga.AttrFetcherTest do
  use MangaWatcher.DataCase, async: true

  import Mox
  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.Manga.AttrFetcher
  alias MangaWatcher.PreviewUploader
  alias MangaWatcher.Series.UserManga

  @preview_image File.read!("test/support/fixtures/preview.png")

  setup do
    website_fixture(base_url: "mangasource.com")
    verify_on_exit!()
  end

  # an original without its thumb, as left behind by a failed thumb conversion
  defp store_original_only(binary) do
    storage_dir =
      Path.join(
        Application.get_env(:waffle, :storage_dir_prefix),
        PreviewUploader.storage_dir(:original, nil)
      )

    name = "original_only_#{System.unique_integer([:positive])}"
    File.mkdir_p!(storage_dir)
    File.write!(Path.join(storage_dir, "#{name}.png"), binary)

    on_exit(fn ->
      File.rm(Path.join(storage_dir, "#{name}.png"))
      File.rm(Path.join(storage_dir, "#{name}_thumb.webp"))
    end)

    "#{name}.png"
  end

  describe "preview_filename/3" do
    test "combines a slug of the name with a hash of the manga url" do
      assert AttrFetcher.preview_filename(
               "My Manga: Part 2!",
               "https://a.com/1",
               "https://c.com/x.JPG"
             ) =~
               ~r/^my_manga_part_2_[0-9a-f]{12}\.jpg$/
    end

    test "is unique for names without latin letters" do
      a = AttrFetcher.preview_filename("나 혼자만 레벨업", "https://a.com/1", "https://c.com/x.jpg")
      b = AttrFetcher.preview_filename("転生したらスライム", "https://a.com/2", "https://c.com/x.jpg")

      assert a =~ ~r/^[0-9a-f]{12}\.jpg$/
      assert a != b
    end

    test "ignores the query string of the preview url" do
      assert AttrFetcher.preview_filename("X", "https://a.com/1", "https://c.com/x.webp?w=300") =~
               ~r/^x_[0-9a-f]{12}\.webp$/
    end
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
        {:ok, @preview_image}
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
      assert {:ok, true} = PreviewUploader.stored(attrs.preview, :thumb)
    end

    @tag :capture_log
    test "stores no preview if the downloaded preview is not an image" do
      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/2" ->
        {:ok, "<html>manga page</html>"}
      end)
      |> expect(:download, fn "https://cdn.mangasource.com/blocked.jpg", _headers ->
        {:ok, "<html>access denied</html>"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok,
         %{
           name: "Blocked Manga",
           last_chapter: 5,
           preview: "https://cdn.mangasource.com/blocked.jpg"
         }}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(%{url: "https://mangasource.com/manga/2"}, deps)
      assert attrs.name == "Blocked Manga"
      assert attrs.preview == nil
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
        binary: @preview_image
      })

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.preview == "existing_preview.jpg"
    end

    @tag :capture_log
    test "generates a missing thumb from the stored original" do
      name = store_original_only(@preview_image)

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" -> {:ok, "<html>ok</html>"} end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok,
         %{name: "My Manga", last_chapter: 5, preview: "https://cdn.mangasource.com/preview.jpg"}}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      manga_attrs = %{url: "https://mangasource.com/manga/1", preview: name}
      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.preview == name
      assert {:ok, true} = PreviewUploader.stored(name, :thumb)
    end

    @tag :capture_log
    test "redownloads the preview if the stored original is not an image" do
      name = store_original_only("<html>blocked</html>")

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" -> {:ok, "<html>ok</html>"} end)
      |> expect(:download, fn "https://cdn.mangasource.com/preview.jpg", _referer ->
        {:ok, @preview_image}
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

      manga_attrs = %{url: "https://mangasource.com/manga/1", preview: name}
      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.preview != name
      assert {:ok, true} = PreviewUploader.stored(attrs.preview, :thumb)
    end

    test "keeps the existing preview if a new one cannot be stored" do
      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>ok</html>"}
      end)
      |> expect(:download, fn "https://cdn.mangasource.com/preview.jpg", _headers ->
        {:ok, "<html>access denied</html>"}
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

      manga_attrs = %{url: "https://mangasource.com/manga/1", preview: "missing_preview.jpg"}

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)
      assert attrs.preview == "missing_preview.jpg"
    end

    @tag :capture_log
    test "keeps the existing preview if the preview download fails" do
      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>ok</html>"}
      end)
      |> expect(:download, fn "https://cdn.mangasource.com/preview.jpg", _headers ->
        {:error, :timeout}
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

      manga_attrs = %{url: "https://mangasource.com/manga/1", preview: "missing_preview.jpg"}

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)
      assert attrs.preview == "missing_preview.jpg"
    end

    test "does not return associations from existing manga attrs" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1",
        tags: [],
        user_mangas: [%UserManga{user_id: 1, manga_id: 1, last_read_chapter: 4}]
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>manga page</html>"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok, %{name: "My Manga", last_chapter: 5, preview: nil}}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)

      assert attrs.url == "https://mangasource.com/manga/1"
      assert attrs.name == "My Manga"
      assert attrs.last_chapter == 5
      refute Map.has_key?(attrs, :tags)
      refute Map.has_key?(attrs, :user_mangas)
    end

    test "preserves user-submitted tag params" do
      manga_attrs = %{
        url: "https://mangasource.com/manga/1",
        tags: "shoujo-ai, yuri"
      }

      MangaWatcher.DownloaderMock
      |> expect(:download, fn "https://mangasource.com/manga/1" ->
        {:ok, "<html>manga page</html>"}
      end)

      MangaWatcher.PageParserMock
      |> expect(:parse, fn _html, _website ->
        {:ok, %{name: "My Manga", last_chapter: 5, preview: nil}}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} = AttrFetcher.fetch(manga_attrs, deps)
      assert attrs.tags == "shoujo-ai, yuri"
    end

    test "takes asura attrs from its api instead of the page" do
      website_fixture(base_url: "asurascans.com")
      api_url = "https://api.asurascans.com/api/series/some-manga-f212c582"

      MangaWatcher.DownloaderMock
      |> expect(:download, fn ^api_url ->
        {:ok, %{"series" => %{"title" => "Some Manga", "cover" => nil}}}
      end)
      |> expect(:download, fn ^api_url <> "/chapters" ->
        {:ok, %{"data" => [%{"number" => 7, "is_premium" => false}]}}
      end)

      deps = %{
        downloader: MangaWatcher.DownloaderMock,
        page_parser: MangaWatcher.PageParserMock
      }

      assert {:ok, attrs} =
               AttrFetcher.fetch(
                 %{url: "https://asurascans.com/comics/some-manga-f212c582"},
                 deps
               )

      assert attrs.name == "Some Manga"
      assert attrs.last_chapter == 7
    end
  end
end
