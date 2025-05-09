defmodule MangaWatcher.SeriesTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.Series

  describe "mangas" do
    alias MangaWatcher.Series.Manga

    import MangaWatcher.SeriesFixtures

    @invalid_attrs %{last_chapter: nil, last_read_chapter: nil, name: nil, url: nil}

    def ids(records) do
      records |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "list_mangas/0 returns all mangas" do
      manga = manga_fixture()
      assert Series.list_mangas() == [manga]
    end

    test "get_manga!/1 returns the manga with given id" do
      manga = manga_fixture() |> Repo.preload([:tags, :user_mangas])
      assert Series.get_manga!(manga.id) == manga
    end

    test "create_manga/1 with valid data creates a manga" do
      valid_attrs = default_manga_attrs()

      assert {:ok, %Manga{} = manga} = Series.create_manga(valid_attrs)
      assert manga.url == valid_attrs.url
    end

    test "create_manga/1 with tags creates a manga and tags" do
      valid_attrs =
        Map.merge(default_manga_attrs(), %{
          url: "http://mangasource.com/url",
          tags: "shoujo-ai, yuri"
        })

      assert {:ok, %Manga{} = manga} = Series.create_manga(valid_attrs)
      assert manga.url == "http://mangasource.com/url"
      manga = Repo.preload(manga, :tags)
      assert length(manga.tags) == 2
    end

    test "create_manga/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Series.create_manga(@invalid_attrs)
    end

    test "update_manga/2 with valid data updates the manga" do
      manga = manga_fixture() |> Repo.preload([:tags])

      update_attrs = %{
        last_chapter: 43,
        url: "http://some/updated/url",
        tags: "example"
      }

      assert {:ok, %Manga{} = manga} = Series.update_manga(manga, update_attrs)
      assert manga.last_chapter == 43
      assert manga.url == "http://some/updated/url"
      manga = Repo.preload(manga, :tags)
      assert length(manga.tags) == 1
    end

    test "update_manga/2 with invalid data returns error changeset" do
      manga = manga_fixture() |> Repo.preload([:tags, :user_mangas])
      assert {:error, %Ecto.Changeset{}} = Series.update_manga(manga, @invalid_attrs)
      assert manga == Series.get_manga!(manga.id)
    end

    test "delete_manga/1 deletes the manga" do
      manga = manga_fixture()
      assert {:ok, %Manga{}} = Series.delete_manga(manga)
      assert_raise Ecto.NoResultsError, fn -> Series.get_manga!(manga.id) end
    end

    test "change_manga/1 returns a manga changeset" do
      manga = manga_fixture()
      assert %Ecto.Changeset{} = Series.change_manga(manga)
    end

    test "list_mangas_for_update/0 returns only mangas that need updates" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Manga with "stale" tag and old enough
      stale_manga =
        manga_fixture_with_tags(%{
          updated_at: NaiveDateTime.add(now, -2, :day),
          tags: ["stale"]
        })

      # Manga with "stale" tag but updated recently
      fresh_stale_manga =
        manga_fixture_with_tags(%{
          updated_at: NaiveDateTime.add(now, -12, :hour),
          tags: ["stale", "fresh_wink"]
        })

      # Manga without "stale" tag and old enough
      normal_manga =
        manga_fixture_with_tags(%{
          updated_at: NaiveDateTime.add(now, -15, :day),
          tags: []
        })

      # Manga without "stale" tag but updated recently
      fresh_normal_manga =
        manga_fixture_with_tags(%{
          updated_at: NaiveDateTime.add(now, -15, :minute),
          tags: []
        })

      # Manga with "broken" tag, should be excluded regardless of other tags
      broken_manga =
        manga_fixture_with_tags(%{
          updated_at: NaiveDateTime.add(now, -365, :day),
          tags: ["broken", "stale", "fresh_wink"]
        })

      result = Series.list_mangas_for_update()

      result_ids = ids(result)

      assert stale_manga.id in result_ids
      assert normal_manga.id in result_ids

      refute fresh_stale_manga.id in result_ids
      refute fresh_normal_manga.id in result_ids
      refute broken_manga.id in result_ids
    end
  end

  describe "websites" do
    alias MangaWatcher.Series.Website

    import MangaWatcher.SeriesFixtures

    @invalid_attrs %{base_url: nil, title_regex: nil, links_regex: nil}

    test "list_websites/0 returns websites sorted by mangas count" do
      website1 = website_fixture()
      manga_fixture(%{url: website1.base_url <> "/1"})
      website2 = website_fixture()
      manga_fixture(%{url: website2.base_url <> "/2"})
      manga_fixture(%{url: website2.base_url <> "/3"})
      assert Series.list_websites() == [website2, website1]
    end

    test "get_website!/1 returns the website with given id" do
      website = website_fixture()
      assert Series.get_website!(website.id) == website
    end

    test "create_website/1 with valid data creates a website" do
      valid_attrs = %{
        base_url: "http://some.base.url/without_path",
        title_regex: "some title_regex",
        links_regex: "some links_regex",
        preview_regex: "some preview_regex"
      }

      assert {:ok, %Website{} = website} = Series.create_website(valid_attrs)
      assert website.base_url == "some.base.url"
      assert website.title_regex == "some title_regex"
      assert website.links_regex == "some links_regex"
      assert website.preview_regex == "some preview_regex"
    end

    test "create_website/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Series.create_website(@invalid_attrs)
    end

    test "update_website/2 with valid data updates the website" do
      website = website_fixture()

      update_attrs = %{
        base_url: "http://some.updated.url/no_path",
        title_regex: "some updated title_regex",
        links_regex: "some updated links_regex"
      }

      assert {:ok, %Website{} = website} = Series.update_website(website, update_attrs)
      assert website.base_url == "some.updated.url"
      assert website.title_regex == "some updated title_regex"
      assert website.links_regex == "some updated links_regex"
    end

    test "update_website/2 with invalid data returns error changeset" do
      website = website_fixture()
      assert {:error, %Ecto.Changeset{}} = Series.update_website(website, @invalid_attrs)
      assert website == Series.get_website!(website.id)
    end

    test "delete_website/1 deletes the website" do
      website = website_fixture()
      assert {:ok, %Website{}} = Series.delete_website(website)
      assert_raise Ecto.NoResultsError, fn -> Series.get_website!(website.id) end
    end

    test "change_website/1 returns a website changeset" do
      website = website_fixture()
      assert %Ecto.Changeset{} = Series.change_website(website)
    end
  end
end
