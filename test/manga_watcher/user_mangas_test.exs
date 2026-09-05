defmodule MangaWatcher.UserMangasTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.Series
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

      # both mangas tie on unread count and updated_at, so their relative order is undefined
      assert ids(UserMangas.filter_mangas(user.id, ["seinen", "shoujo"], [])) |> Enum.sort() ==
               Enum.sort([m1.id, m2.id])
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

    test "list_mangas/1 and filter_mangas/3 preload only the current user's user_manga", %{
      user: user
    } do
      other_user = user_fixture()

      manga =
        manga_for_user_fixture(user, %{last_chapter: 10, user_manga: %{last_read_chapter: 3}})

      {:ok, _} =
        UserMangas.create_user_manga(%{
          manga_id: manga.id,
          user_id: other_user.id,
          last_read_chapter: 8
        })

      for {list_user, expected_chapter} <- [{user, 3}, {other_user, 8}] do
        for mangas <- [
              UserMangas.list_mangas(list_user.id),
              UserMangas.filter_mangas(list_user.id, [], [])
            ] do
          assert [%{id: id, user_mangas: [user_manga]}] = mangas
          assert id == manga.id
          assert user_manga.user_id == list_user.id
          assert user_manga.last_read_chapter == expected_chapter
        end
      end
    end

    test "list_mangas/0 returns all user mangas in correct order", %{user: user} do
      m1 = manga_for_user_fixture(user, %{last_chapter: 10, user_manga: %{last_read_chapter: 7}})
      m2 = manga_for_user_fixture(user, %{last_chapter: 15, user_manga: %{last_read_chapter: 13}})
      m3 = manga_for_user_fixture(user, %{last_chapter: 20, user_manga: %{last_read_chapter: 19}})

      manga_for_user_fixture(user_fixture(), %{})

      assert ids(UserMangas.list_mangas(user.id)) == ids([m1, m2, m3])
    end

    defp month_ago_plus(days) do
      NaiveDateTime.utc_now()
      |> NaiveDateTime.shift(month: -1, day: days)
      |> NaiveDateTime.truncate(:second)
    end

    test "create_user_manga/1 sets last_read_at to now by default", %{user: user} do
      manga = manga_for_user_fixture(user)
      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), user_manga.last_read_at) < 5
    end

    test "create_user_manga/1 accepts explicit last_read_at", %{user: user} do
      last_read_at = month_ago_plus(-10)
      manga = manga_for_user_fixture(user, %{user_manga: %{last_read_at: last_read_at}})
      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      assert user_manga.last_read_at == last_read_at
    end

    test "update_user_manga/2 bumps last_read_at when last read chapter changes", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 1, last_read_at: month_ago_plus(-10)}
        })

      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      {:ok, updated} = UserMangas.update_user_manga(user_manga, %{last_read_chapter: 5})
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), updated.last_read_at) < 5
    end

    test "update_user_manga/2 keeps last_read_at when last read chapter is unchanged", %{
      user: user
    } do
      last_read_at = month_ago_plus(-10)

      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 1, last_read_at: last_read_at}
        })

      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      {:ok, updated} = UserMangas.update_user_manga(user_manga, %{last_read_chapter: 1})
      assert updated.last_read_at == last_read_at
    end

    test "manga_state/1 is :broken when updates keep failing", %{user: user} do
      manga = manga_for_user_fixture(user, %{last_chapter: 5})
      {:ok, _} = MangaWatcher.Series.update_manga(manga, %{failed_updates: 6})
      assert UserMangas.manga_state(UserMangas.get_manga!(user.id, manga.id)) == :broken
    end

    test "manga_state/1 is :read when there are no unread chapters", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 5, last_read_at: month_ago_plus(-10)}
        })

      assert UserMangas.manga_state(UserMangas.get_manga!(user.id, manga.id)) == :read
    end

    test "manga_state/1 is :unread when read recently", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 1, last_read_at: month_ago_plus(1)}
        })

      assert UserMangas.manga_state(UserMangas.get_manga!(user.id, manga.id)) == :unread
    end

    test "manga_state/1 is :dormant when not read for over a month", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 1, last_read_at: month_ago_plus(-1)}
        })

      assert UserMangas.manga_state(UserMangas.get_manga!(user.id, manga.id)) == :dormant
    end

    defp dormant_manga(user, attrs \\ %{}) do
      manga_for_user_fixture(
        user,
        Map.merge(
          %{
            last_chapter: 5,
            user_manga: %{last_read_chapter: 1, last_read_at: month_ago_plus(-1)}
          },
          attrs
        )
      )
    end

    test "dormant?/1 is true when every follower is dormant", %{user: user} do
      manga = dormant_manga(user)
      assert UserMangas.dormant?(Series.get_manga!(manga.id))
    end

    test "dormant?/1 loads user_mangas when they are not preloaded", %{user: user} do
      manga = dormant_manga(user)
      assert UserMangas.dormant?(manga)
    end

    test "dormant?/1 is false for a manga read recently", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 1, last_read_at: month_ago_plus(1)}
        })

      refute UserMangas.dormant?(Series.get_manga!(manga.id))
    end

    test "dormant?/1 is false for a fully read manga", %{user: user} do
      manga =
        manga_for_user_fixture(user, %{
          last_chapter: 5,
          user_manga: %{last_read_chapter: 5, last_read_at: month_ago_plus(-10)}
        })

      refute UserMangas.dormant?(Series.get_manga!(manga.id))
    end

    test "dormant?/1 is false when any follower is still active", %{user: user} do
      manga = dormant_manga(user)

      {:ok, _} =
        UserMangas.create_user_manga(%{
          manga_id: manga.id,
          user_id: user_fixture().id,
          last_read_chapter: 1,
          last_read_at: month_ago_plus(1)
        })

      refute UserMangas.dormant?(Series.get_manga!(manga.id))
    end

    test "dormant?/1 is false for a manga nobody follows" do
      refute UserMangas.dormant?(manga_fixture())
    end

    test "update_user_manga/2 removes the dormant tag once the manga is read", %{user: user} do
      manga = dormant_manga(user)
      {:ok, manga} = Series.add_manga_tag(manga, "dormant")
      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      {:ok, _} = UserMangas.update_user_manga(user_manga, %{last_read_chapter: 5})
      refute Series.manga_has_tag?(Series.get_manga!(manga.id), "dormant")
    end

    test "update_user_manga/2 keeps the dormant tag while the manga stays dormant", %{
      user: user
    } do
      manga = dormant_manga(user)
      {:ok, manga} = Series.add_manga_tag(manga, "dormant")
      [user_manga] = Repo.preload(manga, :user_mangas).user_mangas

      # editing to the same chapter doesn't count as reading
      {:ok, _} = UserMangas.update_user_manga(user_manga, %{last_read_chapter: 1})
      assert Series.manga_has_tag?(Series.get_manga!(manga.id), "dormant")
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
