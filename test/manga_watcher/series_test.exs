defmodule MangaWatcher.SeriesTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.Series

  describe "mangas" do
    alias MangaWatcher.Series.Manga

    import MangaWatcher.SeriesFixtures

    @invalid_attrs %{last_chapter: nil, last_read_chapter: nil, name: nil, url: nil}

    test "list_mangas/0 returns all mangas" do
      manga = manga_fixture()
      assert Series.list_mangas() == [manga]
    end

    test "get_manga!/1 returns the manga with given id" do
      manga = manga_fixture() |> Repo.preload(:tags)
      assert Series.get_manga!(manga.id) == manga
    end

    test "create_manga/1 with valid data creates a manga" do
      valid_attrs = %{url: "http://new/url"}

      assert {:ok, %Manga{} = manga} = Series.create_manga(valid_attrs)
      assert manga.url == "http://new/url"
    end

    test "create_manga/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Series.create_manga(@invalid_attrs)
    end

    test "update_manga/2 with valid data updates the manga" do
      manga = manga_fixture()

      update_attrs = %{
        last_chapter: 43,
        last_read_chapter: 43,
        url: "http://some/updated/url"
      }

      assert {:ok, %Manga{} = manga} = Series.update_manga(manga, update_attrs)
      assert manga.last_chapter == 43
      assert manga.last_read_chapter == 43
      assert manga.url == "http://some/updated/url"
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
end
