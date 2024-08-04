defmodule MangaWatcher.UserMangasTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.UserMangas
  alias MangaWatcher.Series.UserManga

  describe "mangas" do
    import MangaWatcher.SeriesFixtures
    import MangaWatcher.AccountsFixtures

    setup do
      website_fixture()
      {:ok, user: user_fixture()}
    end

    def ids(records) do
      records |> Enum.map(& &1.id) |> Enum.sort()
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

      assert ids(UserMangas.filter_mangas(user.id, ["seinen", "shoujo"], ["school", "josei"])) ==
               [
                 m2.id
               ]
    end

    test "list_mangas/0 returns all user mangas", %{user: user} do
      m1 = manga_for_user_fixture(user, %{url: "http://mangasource.com/1", tags: "seinen"})

      manga_for_user_fixture(user_fixture(), %{url: "http://mangasource.com/2", tags: "seinen"})

      assert ids(UserMangas.list_mangas(user.id)) == [m1.id]
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

    test "add_manga/2 with new manga creates a manga", %{user: user} do
      valid_attrs = %{url: "http://mangasource.com/url"}

      assert {:ok, %UserManga{} = user_manga} = UserMangas.add_manga(user.id, valid_attrs)
      assert user_manga.user_id == user.id
      assert user_manga.manga.url == "http://mangasource.com/url"
    end

    test "add_manga/2 with existing manga assigns existing manga", %{user: user} do
      manga = manga_fixture()
      attrs = %{url: manga.url}

      assert {:ok, %UserManga{} = user_manga} = UserMangas.add_manga(user.id, attrs)
      assert user_manga.user_id == user.id
      assert user_manga.manga.id == manga.id
    end

    test "add_manga/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = UserMangas.add_manga(user.id, %{url: ""})
    end
  end
end
