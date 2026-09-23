defmodule MangaWatcherWeb.MangaLiveTest do
  use MangaWatcherWeb.ConnCase

  import Phoenix.LiveViewTest
  import MangaWatcher.SeriesFixtures

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

  defp tag_manga(manga, tags) do
    {:ok, manga} =
      manga
      |> MangaWatcher.Repo.preload([:tags])
      |> Series.update_manga(%{tags: tags})

    manga
  end

  defp tag_prefs_cookie(include, exclude) do
    %{include: include, exclude: exclude}
    |> Jason.encode!()
    |> URI.encode(&URI.char_unreserved?/1)
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

    test "shows stale mangas", %{conn: conn, user: user} do
      stale = manga_for_user_fixture(user, %{name: "Stale Manga", tags: "stale"})

      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{stale.id}") |> render() =~ "⏳"
    end

    test "shows dormant mangas", %{conn: conn, user: user} do
      dormant =
        manga_for_user_fixture(user, %{
          name: "Dormant Manga",
          last_chapter: 10,
          tags: "dormant",
          user_manga: %{last_read_chapter: 1}
        })

      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{dormant.id}") |> render() =~ "💤"

      index_live |> element("#mangas-#{dormant.id} button", "Mark as read") |> render_click()

      refute index_live |> element("#mangas-#{dormant.id}") |> render() =~ "💤"
    end

    test "filters mangas by tag prefs from connect params", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      {:ok, _index_live, html} = live(conn, ~p"/mangas")
      assert html =~ manga.name

      {:ok, _index_live, html} =
        conn
        |> put_connect_params(%{"tag_prefs" => tag_prefs_cookie([], ["seinen"])})
        |> live(~p"/mangas")

      refute html =~ manga.name
    end

    test "filters mangas by tag prefs cookie on disconnected render", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      html =
        conn
        |> put_req_cookie("tag_prefs", tag_prefs_cookie([], ["seinen"]))
        |> get(~p"/mangas")
        |> html_response(200)

      refute html =~ manga.name
    end

    test "ignores malformed tag prefs cookie", %{conn: conn, manga: manga} do
      {:ok, _index_live, html} =
        conn
        |> put_connect_params(%{"tag_prefs" => "%E0not-json"})
        |> live(~p"/mangas")

      assert html =~ manga.name
    end

    test "clicking a tag pushes updated prefs", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")
      tag = Series.list_tags() |> Enum.find(&(&1.name == "seinen"))

      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      index_live
      |> element("button[phx-value-id='#{tag.id}']")
      |> render_click()

      assert_push_event(index_live, "tag_prefs", %{include: ["seinen"], exclude: []})
      assert render(index_live) =~ manga.name

      index_live
      |> element("button[phx-value-id='#{tag.id}']")
      |> render_click()

      assert_push_event(index_live, "tag_prefs", %{include: [], exclude: ["seinen"]})
      refute render(index_live) =~ manga.name
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
