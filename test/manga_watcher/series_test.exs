defmodule MangaWatcher.SeriesTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.Series

  describe "mangas" do
    alias MangaWatcher.Series.Manga

    import MangaWatcher.SeriesFixtures

    @invalid_attrs %{last_chapter: nil, last_read_chapter: nil, name: nil, url: nil}

    setup do
      website_fixture()
      :ok
    end

    def ids(records) do
      records |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "filter_mangas/2 returns all mangas with empty input" do
      manga = manga_fixture()
      assert Series.filter_mangas([], []) == [manga]
    end

    test "filter_mangas/2 excludes correct tags" do
      _m1 = manga_fixture(%{url: "http://mangasource.com/1", tags: "seinen, school"})
      _m2 = manga_fixture(%{url: "http://mangasource.com/2", tags: "shoujo"})
      m3 = manga_fixture(%{url: "http://mangasource.com/3", tags: "josei"})

      assert ids(Series.filter_mangas([], ["seinen", "shoujo"])) == [m3.id]
    end

    test "filter_mangas/2 includes correct tags" do
      m1 = manga_fixture(%{url: "http://mangasource.com/1", tags: "seinen, school"})
      m2 = manga_fixture(%{url: "http://mangasource.com/2", tags: "shoujo"})
      _m3 = manga_fixture(%{url: "http://mangasource.com/3", tags: "josei"})

      assert ids(Series.filter_mangas(["seinen", "shoujo"], [])) == [m1.id, m2.id]
    end

    test "filter_mangas/2 correctly mixes include and exclude" do
      _m1 = manga_fixture(%{url: "http://mangasource.com/1", tags: "seinen, school"})
      m2 = manga_fixture(%{url: "http://mangasource.com/2", tags: "shoujo"})
      _m3 = manga_fixture(%{url: "http://mangasource.com/3", tags: "josei"})

      assert ids(Series.filter_mangas(["seinen", "shoujo"], ["school", "josei"])) == [m2.id]
    end

    test "list_mangas/0 returns all mangas" do
      manga = manga_fixture()
      assert Series.list_mangas() == [manga]
    end

    test "get_manga!/1 returns the manga with given id" do
      manga = manga_fixture() |> Repo.preload(:tags)
      assert Series.get_manga!(manga.id) == manga
    end

    test "create_manga/1 with valid data creates a manga" do
      valid_attrs = %{url: "http://mangasource.com/url"}

      assert {:ok, %Manga{} = manga} = Series.create_manga(valid_attrs)
      assert manga.url == "http://mangasource.com/url"
    end

    test "create_manga/1 with tags creates a manga and tags" do
      valid_attrs = %{url: "http://mangasource.com/url", tags: "shoujo-ai, yuri"}

      assert {:ok, %Manga{} = manga} = Series.create_manga(valid_attrs)
      assert manga.url == "http://mangasource.com/url"
      manga = Repo.preload(manga, :tags)
      assert length(manga.tags) == 2
    end

    test "create_manga/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Series.create_manga(@invalid_attrs)
    end

    test "update_manga/2 with valid data updates the manga" do
      manga = manga_fixture() |> Repo.preload(:tags)

      update_attrs = %{
        last_chapter: 43,
        last_read_chapter: 43,
        url: "http://some/updated/url",
        tags: "example"
      }

      assert {:ok, %Manga{} = manga} = Series.update_manga(manga, update_attrs)
      assert manga.last_chapter == 43
      assert manga.last_read_chapter == 43
      assert manga.url == "http://some/updated/url"
      manga = Repo.preload(manga, :tags)
      assert length(manga.tags) == 1
    end

    test "update_manga/2 with invalid data returns error changeset" do
      manga = manga_fixture() |> Repo.preload(:tags)
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

    test "refresh_all_manga/0 doesn't throw errors" do
      manga = manga_fixture()
      assert :ok = Series.refresh_all_manga()
      assert [manga] == Series.list_mangas()
    end
  end

  describe "websites" do
    alias MangaWatcher.Series.Website

    import MangaWatcher.SeriesFixtures

    @invalid_attrs %{base_url: nil, title_regex: nil, links_regex: nil}

    test "list_websites/0 returns all websites" do
      website = website_fixture()
      assert Series.list_websites() == [website]
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
