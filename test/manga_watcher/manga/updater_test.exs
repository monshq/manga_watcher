defmodule MangaWatcher.Manga.UpdaterTest do
  use MangaWatcher.DataCase, async: false

  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.Repo

  setup do
    website_fixture()
    :ok
  end

  describe "update/1 — success path" do
    test "resets failed_updates, stores new preview, and persists changes" do
      manga =
        manga_fixture(%{
          url: "https://mangasource.com/manga/1",
          preview: nil,
          failed_updates: 2,
          last_chapter: 15,
          updated_at: ~N[2025-02-01 00:00:00]
        })

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/1"), do: {:ok, "<html>valid html</html>"}
        def download("https://mangasource.com/preview.jpg", _headers), do: {:ok, "binary preview"}
      end

      defmodule TestPageParser do
        def parse(_html, _website) do
          {:ok, %{name: "Updated Title", preview: "https://mangasource.com/preview.jpg"}}
        end
      end

      updated = Updater.update(manga, %{downloader: TestDownloader, page_parser: TestPageParser})

      assert updated.id == manga.id
      assert updated.failed_updates == 0
      assert updated.preview =~ "updated_title"

      reloaded = Repo.get!(Manga, manga.id)
      assert reloaded.preview == updated.preview
    end

    test "does not update updated_at if attributes are unchanged, but still updates scanned_at" do
      inserted_at = ~N[2025-01-01 00:00:00]
      updated_at = ~N[2025-02-01 00:00:00]

      manga =
        manga_fixture(%{
          name: "Same Name",
          url: "https://mangasource.com/manga/1",
          # auto-name, since file is missing and preview will try to re-create
          preview: "same_name.jpg",
          last_chapter: 15,
          failed_updates: 0,
          inserted_at: inserted_at,
          updated_at: updated_at,
          scanned_at: ~N[2025-03-01 00:00:00]
        })

      defmodule TestDownloaderSame do
        def download("https://mangasource.com/manga/1"), do: {:ok, "<html>same</html>"}
        def download(_url, _headers), do: {:ok, "binary preview"}
      end

      defmodule TestPageParserSame do
        def parse(_html, _website),
          do: {:ok, %{name: "Same Name", preview: "existing.jpg", last_chapter: 15}}
      end

      updated =
        Updater.update(manga, %{downloader: TestDownloaderSame, page_parser: TestPageParserSame})

      reloaded = Repo.get!(Manga, manga.id)

      assert updated.updated_at == updated_at
      assert reloaded.updated_at == updated_at
      assert NaiveDateTime.after?(reloaded.scanned_at, ~N[2025-03-01 00:00:00])
    end
  end

  describe "update/1 — failure path" do
    test "increments failed_updates and marks broken past threshold" do
      manga =
        manga_fixture(%{
          url: "https://mangasource.com/manga/1",
          last_chapter: 15,
          failed_updates: 5
        })

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/1"), do: {:ok, "<html>valid html</html>"}
      end

      defmodule TestPageParser do
        def parse(_html, _website) do
          {:error, :invalid_html}
        end
      end

      errored = Updater.update(manga, %{downloader: TestDownloader, page_parser: TestPageParser})

      assert errored.failed_updates == 6
      # after passing threshold (5), it should have the "broken" tag in DB
      reloaded = Repo.get!(Manga, manga.id) |> Repo.preload(:tags)
      assert "broken" in Enum.map(reloaded.tags, & &1.name)
    end
  end

  describe "plan_update/2" do
    test "returns update plan for fresh manga with preview" do
      manga = %Manga{
        name: "Old Name",
        url: "https://mangasource.com/manga/1",
        preview: nil,
        failed_updates: 3,
        last_chapter: 9,
        updated_at: ~N[2024-12-01 00:00:00]
      }

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/1"), do: {:ok, "<html>test</html>"}
        def download("https://cdn.org/new.jpg", _headers), do: {:ok, "img bytes"}
      end

      defmodule TestPageParser do
        def parse(_html, _website),
          do: {:ok, %{name: "New Name", last_chapter: 10, preview: "https://cdn.org/new.jpg"}}
      end

      assert {:ok, plan} =
               Updater.plan_update(manga, %{
                 downloader: TestDownloader,
                 page_parser: TestPageParser
               })

      assert plan.attrs.name == "New Name"
      assert plan.attrs.preview =~ "new_name"
      assert plan.attrs.failed_updates == 0
      refute plan.mark_stale?
      assert plan.remove_broken?
    end

    test "returns stale?: false for recently updated manga" do
      manga = %Manga{
        name: "X",
        url: "https://mangasource.com/manga/1",
        preview: nil,
        failed_updates: 1,
        updated_at: NaiveDateTime.utc_now()
      }

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/1"), do: {:ok, "<html>new</html>"}
      end

      defmodule TestPageParser do
        def parse(_html, _website), do: {:ok, %{name: "X", preview: nil}}
      end

      assert {:ok, plan} =
               Updater.plan_update(manga, %{
                 downloader: TestDownloader,
                 page_parser: TestPageParser
               })

      refute plan.mark_stale?
    end

    test "returns error if downloader fails" do
      manga = %Manga{
        name: "Y",
        url: "https://mangasource.com/manga/404",
        preview: nil,
        failed_updates: 0,
        updated_at: NaiveDateTime.utc_now()
      }

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/404"), do: {:error, :not_found}
      end

      defmodule TestPageParser do
        def parse(_, _), do: flunk("should not be called")
      end

      assert {:error, :not_found} =
               Updater.plan_update(manga, %{
                 downloader: TestDownloader,
                 page_parser: TestPageParser
               })
    end

    test "returns error if parser fails" do
      manga = %Manga{
        name: "Z",
        url: "https://mangasource.com/manga/bad",
        preview: nil,
        failed_updates: 0,
        updated_at: NaiveDateTime.utc_now()
      }

      defmodule TestDownloader do
        def download("https://mangasource.com/manga/bad"), do: {:ok, "<html>bad</html>"}
      end

      defmodule TestPageParser do
        def parse(_, _), do: {:error, :parse_failed}
      end

      assert {:error, :parse_failed} =
               Updater.plan_update(manga, %{
                 downloader: TestDownloader,
                 page_parser: TestPageParser
               })
    end
  end
end
