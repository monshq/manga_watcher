defmodule MangaWatcher.UserMangasTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.UserMangas

  describe "mangas" do
    import MangaWatcher.SeriesFixtures
    import MangaWatcher.AccountsFixtures

    setup do
      {:ok, user: user_fixture()}
    end

    def ids(records) do
      records |> Enum.map(& &1.id)
    end

    test "filter_mangas/3 returns all user mangas with empty input", %{user: user} do
      manga = manga_for_user_fixture(user)
      assert ids(UserMangas.filter_mangas(user.id, [], [])) == [manga.id]
    end

    test "filter_mangas/3 excludes correct tags", %{user: user} do
      _m1 =
        manga_for_user_fixture(user, %{url: "http://mangasource.com/1", tags: "seinen, school"})

      _m2 = manga_for_user_fixture(user, %{url: "http://mangasource.com/2", tags: "shoujo"})
      m3 = manga_for_user_fixture(user, %{url: "http://mangasource.com/3", tags: "josei"})

      assert ids(UserMangas.filter_mangas(user.id, [], ["seinen", "shoujo"])) == [m3.id]
    end

    test "filter_mangas/3 includes correct tags", %{user: user} do
      m1 =
        manga_for_user_fixture(user, %{url: "http://mangasource.com/1", tags: "seinen, school"})

      m2 = manga_for_user_fixture(user, %{url: "http://mangasource.com/2", tags: "shoujo"})
      _m3 = manga_for_user_fixture(user, %{url: "http://mangasource.com/3", tags: "josei"})

      assert ids(UserMangas.filter_mangas(user.id, ["seinen", "shoujo"], [])) == [m1.id, m2.id]
    end

    test "filter_mangas/3 correctly mixes include and exclude", %{user: user} do
      _m1 =
        manga_for_user_fixture(user, %{url: "http://mangasource.com/1", tags: "seinen, school"})

      m2 = manga_for_user_fixture(user, %{url: "http://mangasource.com/2", tags: "shoujo"})
      _m3 = manga_for_user_fixture(user, %{url: "http://mangasource.com/3", tags: "josei"})

      mangas = UserMangas.filter_mangas(user.id, ["seinen", "shoujo"], ["school", "josei"])
      assert ids(mangas) == [m2.id]
    end

    test "filter_mangas/3 returns all user mangas in correct order", %{user: user} do
      m1 = manga_for_user_fixture(user, %{last_chapter: 10, user_manga: %{last_read_chapter: 7}})
      m2 = manga_for_user_fixture(user, %{last_chapter: 15, user_manga: %{last_read_chapter: 13}})
      m3 = manga_for_user_fixture(user, %{last_chapter: 20, user_manga: %{last_read_chapter: 19}})

      manga_for_user_fixture(user_fixture(), %{})

      mangas = UserMangas.filter_mangas(user.id, [], [])
      assert ids(mangas) == ids([m1, m2, m3])
    end

    test "list_mangas/0 returns all user mangas in correct order", %{user: user} do
      m1 = manga_for_user_fixture(user, %{last_chapter: 10, user_manga: %{last_read_chapter: 7}})
      m2 = manga_for_user_fixture(user, %{last_chapter: 15, user_manga: %{last_read_chapter: 13}})
      m3 = manga_for_user_fixture(user, %{last_chapter: 20, user_manga: %{last_read_chapter: 19}})

      manga_for_user_fixture(user_fixture(), %{})

      assert ids(UserMangas.list_mangas(user.id)) == ids([m1, m2, m3])
    end

    test "get_manga!/2 returns the manga for user", %{user: user} do
      manga = manga_for_user_fixture(user) |> Repo.preload([:tags, :user_mangas])
      assert UserMangas.get_manga!(user.id, manga.id) == manga
    end

    test "get_manga!/2 doesn't return non-user manga", %{user: user} do
      manga = manga_for_user_fixture(user) |> Repo.preload([:tags, :user_mangas])

      assert_raise(Ecto.NoResultsError, fn ->
        UserMangas.get_manga!(user.id + 1, manga.id)
      end)
    end
  end
end
