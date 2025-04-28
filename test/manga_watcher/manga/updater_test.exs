defmodule MangaWatcher.Manga.UpdaterTest do
  use MangaWatcher.DataCase, async: true

  import MangaWatcher.SeriesFixtures
  import Mox

  alias MangaWatcher.AttrFetcherMock
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.Repo

  setup :verify_on_exit!

  describe "update/1 — success path" do
    test "resets failed_updates, persists changes, updates timestamps" do
      manga =
        manga_raw_fixture(%{
          failed_updates: 2,
          last_chapter: 15,
          updated_at: ~N[2025-02-01 00:00:00],
          last_chapter_updated_at: ~N[2025-01-01 00:00:00]
        })

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs ->
        {:ok, %{name: "Updated Title", preview: "updated_title.jpg", last_chapter: 16}}
      end)

      updated = Updater.update(manga, AttrFetcherMock)

      assert updated.id == manga.id
      assert updated.failed_updates == 0
      assert updated.preview == "updated_title.jpg"
      assert updated.last_chapter == 16

      reloaded = Repo.get!(Manga, manga.id)

      assert reloaded.preview == updated.preview
      assert NaiveDateTime.after?(reloaded.updated_at, manga.updated_at)
      assert NaiveDateTime.after?(reloaded.last_chapter_updated_at, manga.last_chapter_updated_at)
    end

    test "changes updated_at if attributes are unchanged and keeps last_chapter_updated_at" do
      inserted_at = ~N[2025-01-01 00:00:00]
      updated_at = ~N[2025-02-01 00:00:00]
      last_chapter_updated_at = ~N[2025-03-01 00:00:00]

      manga =
        manga_raw_fixture(%{
          name: "Same Name",
          preview: "same_name.jpg",
          last_chapter: 15,
          failed_updates: 0,
          inserted_at: inserted_at,
          updated_at: updated_at,
          last_chapter_updated_at: last_chapter_updated_at
        })

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs ->
        {:ok, %{name: "Same Name", preview: "same_name.jpg", last_chapter: 15}}
      end)

      updated = Updater.update(manga, AttrFetcherMock)

      reloaded = Repo.get!(Manga, manga.id)

      assert NaiveDateTime.after?(updated.updated_at, manga.updated_at)
      assert NaiveDateTime.after?(reloaded.updated_at, manga.updated_at)

      assert updated.last_chapter_updated_at == last_chapter_updated_at
      assert reloaded.last_chapter_updated_at == last_chapter_updated_at
    end
  end

  describe "update/1 — failure path" do
    @tag :capture_log
    test "increments failed_updates and marks broken past threshold" do
      minute_ago =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1, :minute)
        |> NaiveDateTime.truncate(:second)

      manga =
        manga_raw_fixture(%{
          last_chapter: 15,
          failed_updates: 5,
          updated_at: minute_ago
        })

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs -> {:error, :parse_failed} end)

      errored = Updater.update(manga, AttrFetcherMock)

      assert errored.failed_updates == 6

      reloaded = Repo.get!(Manga, manga.id) |> Repo.preload(:tags)
      assert "broken" in Enum.map(reloaded.tags, & &1.name)

      assert NaiveDateTime.after?(errored.updated_at, manga.updated_at)
      assert NaiveDateTime.after?(reloaded.updated_at, manga.updated_at)
      assert reloaded.last_chapter_updated_at == manga.last_chapter_updated_at
    end
  end

  describe "plan_update/2" do
    test "returns update plan for fresh manga with preview" do
      manga = %Manga{
        name: "Old Name",
        failed_updates: 3,
        last_chapter: 9,
        updated_at: ~N[2024-12-01 00:00:00]
      }

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs ->
        {:ok, %{name: "New Name", preview: "new_name.jpg", last_chapter: 10}}
      end)

      assert {:ok, plan} = Updater.plan_update(manga, AttrFetcherMock)

      assert plan.attrs.name == "New Name"
      assert plan.attrs.preview == "new_name.jpg"
      assert plan.attrs.failed_updates == 0
      refute plan.mark_stale?
      assert plan.remove_broken?
    end

    test "returns stale?: true for not recently updated manga" do
      manga = %Manga{
        failed_updates: 1,
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(-31, :day)
      }

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs ->
        {:ok, %{name: "X", preview: nil}}
      end)

      assert {:ok, plan} = Updater.plan_update(manga, AttrFetcherMock)
      assert plan.mark_stale?
    end

    test "returns error if fetcher fails" do
      manga = %Manga{
        updated_at: NaiveDateTime.utc_now()
      }

      AttrFetcherMock
      |> expect(:fetch, fn _manga_attrs -> {:error, :not_found} end)

      assert {:error, :not_found} = Updater.plan_update(manga, AttrFetcherMock)
    end
  end
end
