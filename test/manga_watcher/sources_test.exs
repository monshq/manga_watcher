defmodule MangaWatcher.SourcesTest do
  use MangaWatcher.DataCase, async: true

  import Mox
  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.DownloaderMock
  alias MangaWatcher.Repo
  alias MangaWatcher.Series
  alias MangaWatcher.Sources

  @deps %{downloader: DownloaderMock}
  @page File.read!("test/support/fixtures/website_pages/asuratoon.html")
  @selectors %{title: "h1.entry-title", links: "#chapterlist a", preview: ".thumbook img"}
  @urls ["https://asuratoon.com/manga/a", "https://asuratoon.com/manga/b"]

  setup :verify_on_exit!

  # serves the fixture page for every url and an image for the preview,
  # `overrides` maps urls to {status, content_type, body}
  defp serve(overrides \\ %{}) do
    stub(DownloaderMock, :fetch, fn url, opts ->
      assert opts[:guard]

      {status, content_type, body} =
        cond do
          Map.has_key?(overrides, url) -> overrides[url]
          String.ends_with?(url, ".png") -> {200, "image/png", "png"}
          true -> {200, "text/html", @page}
        end

      {:ok, %{status: status, url: url, headers: %{"content-type" => [content_type]}, body: body}}
    end)
  end

  defp broken?(manga) do
    manga = Repo.reload!(manga) |> Repo.preload(:tags, force: true)
    manga.failed_updates > 0 or Enum.any?(manga.tags, &(&1.name == "broken"))
  end

  describe "probe/2" do
    test "reports a parseable page and its existing source" do
      serve()
      website_fixture(base_url: "asuratoon.com")

      assert {:ok, result} = Sources.probe("https://asuratoon.com/manga/a", @deps)

      assert result.verdict == :ok
      assert result.status == 200
      assert result.host == "asuratoon.com"
      assert result.existing_source.host == "asuratoon.com"
      assert result.html == @page
    end

    test "reports blocked pages" do
      serve(%{"https://blocked.com/m" => {403, "text/html", "<title>Just a moment...</title>"}})

      assert {:ok, %{verdict: :cloudflare, status: 403, existing_source: nil}} =
               Sources.probe("https://blocked.com/m", @deps)
    end
  end

  describe "test/3" do
    test "reports parsed attributes for working selectors" do
      serve()

      assert [report, _] = Sources.test(@urls, @selectors, @deps)

      assert report.ok
      assert report.errors == []
      assert report.title.value == "Academy’s Undercover Professor"
      assert report.links.max_chapter == 81
      assert %{ok: true, status: 200, content_type: "image/png"} = report.preview.download
    end

    test "explains what is wrong with bad selectors" do
      serve()
      selectors = %{title: "h1, h2", links: "nav a", preview: ".missing img"}

      assert [report] = Sources.test(["https://asuratoon.com/manga/a"], selectors, @deps)

      refute report.ok
      assert Enum.any?(report.errors, &(&1 =~ "title selector matched"))
      assert Enum.any?(report.errors, &(&1 =~ "none has a chapter number"))
      assert Enum.any?(report.errors, &(&1 =~ "preview selector matched 0"))
    end

    test "fails when the preview is protected from hotlinking" do
      preview =
        "https://img.asuracomics.com/unsafe/fit-in/720x936/https://asuratoon.com/wp-content/uploads/2022/06/Academys_Undercover_ProfessorCover_copy.png"

      serve(%{preview => {200, "text/html", "<html>no hotlinking</html>"}})

      assert [report] = Sources.test(["https://asuratoon.com/manga/a"], @selectors, @deps)

      refute report.ok
      assert [error] = report.errors
      assert error =~ "preview download failed"
    end

    test "fails blocked pages without parsing them" do
      serve(%{
        "https://asuratoon.com/manga/a" => {503, "text/html", "<title>Just a moment</title>"}
      })

      assert [report] = Sources.test(["https://asuratoon.com/manga/a"], @selectors, @deps)

      refute report.ok
      assert report.verdict == :cloudflare
      refute Map.has_key?(report, :title)
    end

    test "reports download errors" do
      stub(DownloaderMock, :fetch, fn _url, _opts -> {:error, %RuntimeError{message: "boom"}} end)

      assert [%{ok: false, verdict: :fetch_error, errors: ["boom"]}] =
               Sources.test(["https://asuratoon.com/manga/a"], @selectors, @deps)
    end
  end

  describe "save/5" do
    test "creates a new website when selectors pass on all urls" do
      serve()

      assert {:ok, :created, source, [_, _]} =
               Sources.save("asuratoon.com", @selectors, @urls, [], @deps)

      assert source == %{host: "asuratoon.com", selectors: @selectors}
      assert Series.get_website_by_host("asuratoon.com").links_regex == "#chapterlist a"
    end

    test "does not create a website when selectors fail" do
      serve()
      selectors = %{@selectors | title: "h2"}

      assert {:error, :tests_failed, [%{ok: false}, %{ok: false}]} =
               Sources.save("asuratoon.com", selectors, @urls, [], @deps)

      assert Series.get_website_by_host("asuratoon.com") == nil
    end

    test "requires two different urls of the same host" do
      assert {:error, :invalid_urls, _} =
               Sources.save("asuratoon.com", @selectors, [hd(@urls), hd(@urls) <> "/"], [], @deps)

      assert {:error, :invalid_urls, _} =
               Sources.save(
                 "asuratoon.com",
                 @selectors,
                 [hd(@urls), "https://other.com/m"],
                 [],
                 @deps
               )

      assert {:error, :invalid_urls, _} =
               Sources.save("asuratoon.com", @selectors, nil, [], @deps)
    end

    test "asks for confirmation before updating an existing website" do
      serve()
      website = website_fixture(base_url: "asuratoon.com", title_regex: "h1.old")

      assert {:error, :needs_confirmation, %{current: current, proposed: @selectors, reports: _}} =
               Sources.save("asuratoon.com", @selectors, @urls, [], @deps)

      assert current.title == "h1.old"
      assert Repo.reload!(website).title_regex == "h1.old"
    end

    test "updates a confirmed website, checks its mangas and unbreaks them" do
      serve()
      website = website_fixture(base_url: "asuratoon.com", title_regex: "h1.old")

      manga =
        manga_fixture_with_tags(%{
          url: "https://asuratoon.com/manga/existing",
          failed_updates: 7,
          tags: ["broken"]
        })

      other_host = manga_fixture_with_tags(%{failed_updates: 7, tags: ["broken"]})

      assert {:ok, :updated, _source, reports} =
               Sources.save("asuratoon.com", @selectors, @urls, [confirm: true], @deps)

      assert [:verified, :verified, :existing] = Enum.map(reports, & &1.kind)
      assert Repo.reload!(website).title_regex == "h1.entry-title"
      refute broken?(manga)
      assert broken?(other_host)
    end

    test "ignores existing mangas that are gone from the website" do
      serve(%{"https://asuratoon.com/manga/gone" => {404, "text/html", "not found"}})
      website_fixture(base_url: "asuratoon.com")
      manga_fixture(%{url: "https://asuratoon.com/manga/gone"})

      assert {:ok, :updated, _, _} =
               Sources.save("asuratoon.com", @selectors, @urls, [confirm: true], @deps)
    end

    test "does not update when selectors fail on existing mangas" do
      serve(%{
        "https://asuratoon.com/manga/other" =>
          {200, "text/html", "<h1 class=\"entry-title\">X</h1>"}
      })

      website_fixture(base_url: "asuratoon.com", title_regex: "h1.old")
      manga_fixture(%{url: "https://asuratoon.com/manga/other"})

      assert {:error, :tests_failed, reports} =
               Sources.save("asuratoon.com", @selectors, @urls, [confirm: true], @deps)

      assert %{kind: :existing, ok: false} = List.last(reports)
      assert Series.get_website_by_host("asuratoon.com").title_regex == "h1.old"
    end
  end

  test "list/0 returns websites with their health" do
    website_fixture(base_url: "asuratoon.com")
    manga_fixture(%{url: "https://asuratoon.com/manga/a"})
    manga_fixture_with_tags(%{url: "https://asuratoon.com/manga/b", tags: ["broken"]})

    assert [source] = Sources.list()
    assert %{host: "asuratoon.com", mangas: 2, broken: 1} = source
    assert Enum.sort(source.sample_urls) == @urls
  end
end
