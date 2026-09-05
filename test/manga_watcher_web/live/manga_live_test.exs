defmodule MangaWatcherWeb.MangaLiveTest do
  use MangaWatcherWeb.ConnCase

  import Phoenix.LiveViewTest
  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.Accounts
  alias MangaWatcher.Series
  alias MangaWatcher.UserMangas

  @create_attrs %{url: "http://mangasource.com", tags: "shoujo-ai, yuri"}
  @update_attrs %{url: "http://mangasource.com", tags: "seinen"}
  @invalid_attrs %{url: ""}

  defp create_manga(opts) do
    _website = website_fixture(%{base_url: "http://mangasource.com"})
    manga = manga_for_user_fixture(opts.user)
    %{manga: manga}
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_manga]

    test "lists all mangas", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Manga Watcher"
    end

    test "saves new manga", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("a", "Add manga") |> render_click() =~
               "New Manga"

      assert_patch(index_live, ~p"/mangas/new")

      assert index_live
             |> form("#manga-form", manga: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#manga-form", manga: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/mangas")

      html = render(index_live)
      assert html =~ "Manga created successfully"

      m = Series.list_mangas() |> Enum.find(fn m -> m.url == @create_attrs[:url] end)
      m = Series.get_manga!(m.id)
      assert Enum.map_join(m.tags, ", ", fn t -> t.name end) == "shoujo-ai, yuri"
    end

    test "updates manga in listing", %{conn: conn, manga: manga} do
      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{manga.id} a", "Edit") |> render_click() =~
               "Edit Manga"

      assert_patch(index_live, ~p"/mangas/#{manga}/edit")

      assert index_live
             |> form("#manga-form", manga: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#manga-form", manga: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/mangas")

      html = render(index_live)
      assert html =~ "Manga updated successfully"

      m = Series.get_manga!(manga.id)
      assert m.url == @update_attrs[:url]
      assert Enum.map_join(m.tags, ", ", fn t -> t.name end) == "seinen"
    end

    test "marks manga as read", %{conn: conn, manga: manga, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/mangas")
      user_manga = UserMangas.get_manga!(user.id, manga.id).user_mangas |> hd()

      refute index_live |> element("#mangas-#{manga.id} button", "Mark as read") |> render_click() =~
               "Mark as read"

      updated_um = UserMangas.get_manga!(user.id, manga.id).user_mangas |> hd()
      refute user_manga.last_read_chapter == updated_um.last_read_chapter
      assert updated_um.last_read_chapter == manga.last_chapter
      assert NaiveDateTime.compare(updated_um.last_read_at, user_manga.last_read_at) in [:gt, :eq]
    end

    test "shows dormant mangas", %{conn: conn, user: user} do
      month_and_a_day_ago =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.shift(month: -1, day: -1)
        |> NaiveDateTime.truncate(:second)

      dormant =
        manga_for_user_fixture(user, %{
          name: "Dormant Manga",
          last_chapter: 10,
          user_manga: %{last_read_chapter: 1, last_read_at: month_and_a_day_ago}
        })

      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{dormant.id}") |> render() =~ "💤"

      index_live |> element("#mangas-#{dormant.id} button", "Mark as read") |> render_click()

      refute index_live |> element("#mangas-#{dormant.id}") |> render() =~ "💤"
    end

    test "filters mangas in listing", %{conn: conn, manga: manga, user: user} do
      {:ok, manga} =
        manga
        |> MangaWatcher.Repo.preload([:tags])
        |> Series.update_manga(%{tags: "seinen"})

      {:ok, _index_live, html} = live(conn, ~p"/mangas")
      assert html =~ manga.name

      {:ok, _} = Accounts.update_user_tag_prefs(user, [], ["seinen"])

      {:ok, _index_live, html} = live(conn, ~p"/mangas")
      refute html =~ manga.name
    end

    test "deletes manga in listing", %{conn: conn, manga: manga} do
      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{manga.id} a", "Edit") |> render_click() =~
               "Edit Manga"

      assert index_live |> element("#manga-form button", "Delete") |> render_click()
      refute has_element?(index_live, "#mangas-#{manga.id}")
    end
  end
end
