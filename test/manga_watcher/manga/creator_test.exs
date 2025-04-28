defmodule MangaWatcher.Manga.CreatorTest do
  use MangaWatcher.DataCase

  import Mox
  import MangaWatcher.SeriesFixtures
  import MangaWatcher.AccountsFixtures

  alias MangaWatcher.Manga.Creator
  alias MangaWatcher.Series.UserManga
  alias MangaWatcher.AttrFetcherMock

  setup :verify_on_exit!

  describe "add_for_user/2 with AttrFetcher mocked" do
    setup do
      {:ok, user: user_fixture()}
    end

    test "reuses existing manga and creates user_manga", %{user: user} do
      manga = manga_fixture(%{url: "http://test.manga"})

      assert {:ok, result} = Creator.add_for_user(user.id, %{url: manga.url})

      assert result.manga.id == manga.id
      assert result.manga.url == manga.url

      user_manga = Repo.get_by!(UserManga, manga_id: manga.id, user_id: user.id)
      assert user_manga.last_read_chapter == manga.last_chapter
    end

    test "creates manga with fetched attrs when manga does not exist", %{user: user} do
      url = "http://new.manga"

      AttrFetcherMock
      |> expect(:fetch, fn attrs ->
        {:ok, Map.put(attrs, :url, attrs.url <> "/parsed")}
      end)

      assert {:ok, result} = Creator.add_for_user(user.id, %{url: url}, AttrFetcherMock)

      assert result.manga.url == url <> "/parsed"
      assert Repo.get_by!(UserManga, manga_id: result.manga.id, user_id: user.id)
    end

    @tag capture_log: true
    test "creates manga with original attrs when fetching fails", %{user: user} do
      url = "http://failing.manga"

      AttrFetcherMock
      |> expect(:fetch, fn _attrs ->
        {:error, :some_error}
      end)

      assert {:ok, result} = Creator.add_for_user(user.id, %{url: url}, AttrFetcherMock)

      assert result.manga.url == url
      assert Repo.get_by!(UserManga, manga_id: result.manga.id, user_id: user.id)
    end

    test "returns error if creating user_manga fails", %{user: user} do
      manga = manga_fixture(%{url: "http://failuser.manga"})

      # no need to mock fetch since manga already exists
      assert {:error, _reason} = Creator.add_for_user(user.id + 1_000_000, %{url: manga.url})
    end
  end
end
