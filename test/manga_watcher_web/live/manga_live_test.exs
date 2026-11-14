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

  defp cookie(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp legacy_cookie(include, exclude) do
    %{include: include, exclude: exclude} |> Jason.encode!() |> cookie()
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_manga]

    test "lists all mangas", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Manga Watcher"
    end

    test "shows lazily loaded preview thumbnails", %{conn: conn, user: user} do
      manga_for_user_fixture(user, %{preview: "cover.png"})

      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ ~r/<img src="[^"]*cover_thumb\.webp" loading="lazy"/
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

    test "marks manga as read only for the current user", %{conn: conn, user: user} do
      # the other user follows first, so their record comes first in the preload
      other = MangaWatcher.AccountsFixtures.user_fixture()
      manga = manga_for_user_fixture(other, %{last_chapter: 6})
      {:ok, _} = UserMangas.create_user_manga(%{manga_id: manga.id, user_id: user.id})

      {:ok, index_live, _html} = live(conn, ~p"/mangas")
      index_live |> element("#mangas-#{manga.id} button", "Mark as read") |> render_click()

      manga = Series.get_manga!(manga.id)
      assert UserMangas.user_manga!(manga, user.id).last_read_chapter == 6
      assert UserMangas.user_manga!(manga, other.id).last_read_chapter == 0
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

    test "applies the default filter from connect params", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      {:ok, _index_live, html} = live(conn, ~p"/mangas")
      assert html =~ manga.name

      {:ok, index_live, _html} =
        conn
        |> put_connect_params(%{"filter_base" => cookie("-seinen is:unread")})
        |> live(~p"/mangas")

      refute has_element?(index_live, "#mangas-#{manga.id}")
      assert index_live |> element("#filter-summary") |> render() =~ "-seinen is:unread"
    end

    test "applies the default filter cookie on disconnected render", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      html =
        conn
        |> put_req_cookie("filter_base", cookie("-seinen"))
        |> get(~p"/mangas")
        |> html_response(200)

      refute html =~ manga.name
    end

    test "converts the old tag prefs cookie into a default filter", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      conn =
        conn
        |> put_req_cookie("tag_prefs", legacy_cookie(["josei", "shoujo"], ["seinen"]))
        |> get(~p"/mangas")

      refute html_response(conn, 200) =~ manga.name
      assert conn.resp_cookies["filter_base"].value == cookie("(josei | shoujo) -seinen")
      assert conn.resp_cookies["filter_base"].http_only == false
      assert conn.resp_cookies["tag_prefs"].max_age == 0
    end

    test "ignores a malformed default filter", %{conn: conn, manga: manga} do
      for value <- ["%E0not-utf8", cookie("(seinen")] do
        {:ok, index_live, _html} =
          conn
          |> put_connect_params(%{"filter_base" => value})
          |> live(~p"/mangas")

        assert has_element?(index_live, "#mangas-#{manga.id}")
      end
    end

    test "hides the filter editor until asked", %{conn: conn, manga: manga} do
      tag_manga(manga, "seinen")
      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      refute has_element?(index_live, "#filter-editor")
      refute has_element?(index_live, "#filter-tags button")

      index_live |> element("#filter-toggle") |> render_click()
      assert has_element?(index_live, "#filter-tags button", "seinen")

      index_live |> element("#filter-toggle") |> render_click()
      refute has_element?(index_live, "#filter-editor")
    end

    test "filters by the query in the URL on top of the default", %{conn: conn, user: user} do
      stale = manga_for_user_fixture(user, %{name: "Stale One", tags: "stale, seinen"})
      seinen = manga_for_user_fixture(user, %{name: "Seinen One", tags: "seinen"})
      other = manga_for_user_fixture(user, %{name: "Other One", tags: "josei"})
      conn = put_connect_params(conn, %{"filter_base" => cookie("-stale")})

      {:ok, index_live, _html} = live(conn, ~p"/mangas?q=seinen")
      assert has_element?(index_live, "#mangas-#{seinen.id}")
      refute has_element?(index_live, "#mangas-#{stale.id}")
      refute has_element?(index_live, "#mangas-#{other.id}")

      # the query wins over the default
      {:ok, index_live, _html} = live(conn, ~p"/mangas?q=stale")
      assert has_element?(index_live, "#mangas-#{stale.id}")
      refute has_element?(index_live, "#mangas-#{seinen.id}")
      refute index_live |> element("#filter-summary") |> render() =~ "-stale"

      {:ok, index_live, _html} = live(conn, ~p"/mangas?all=1")
      assert has_element?(index_live, "#mangas-#{stale.id}")
      assert has_element?(index_live, "#mangas-#{other.id}")
    end

    test "typing a query patches the URL", %{conn: conn, manga: manga, user: user} do
      manga = tag_manga(manga, "seinen")
      other = manga_for_user_fixture(user, %{name: "Other One", tags: "josei"})

      {:ok, index_live, _html} = live(conn, ~p"/mangas")
      index_live |> element("#filter-toggle") |> render_click()

      index_live |> form("#filter-query-form", q: "seinen | (josei") |> render_submit()
      assert index_live |> element("#filter-query-error") |> render() =~ "missing )"
      assert has_element?(index_live, "#mangas-#{other.id}")

      index_live |> form("#filter-query-form", q: " -josei ") |> render_submit()
      assert_patch(index_live, ~p"/mangas?q=-josei")
      refute has_element?(index_live, "#filter-query-error")
      assert has_element?(index_live, "#mangas-#{manga.id}")
      refute has_element?(index_live, "#mangas-#{other.id}")
    end

    test "clicking a tag cycles it in the query", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      {:ok, index_live, _html} = live(conn, ~p"/mangas?q=is:unread")
      index_live |> element("#filter-toggle") |> render_click()
      chip = element(index_live, "#filter-tags button", "seinen")

      render_click(chip)
      assert_patch(index_live, ~p"/mangas?#{[q: "is:unread seinen"]}")
      assert has_element?(index_live, "#filter-tags button[data-state=include]", "seinen")
      assert has_element?(index_live, "#mangas-#{manga.id}")

      render_click(chip)
      assert_patch(index_live, ~p"/mangas?#{[q: "is:unread -seinen"]}")
      refute has_element?(index_live, "#mangas-#{manga.id}")

      render_click(chip)
      assert_patch(index_live, ~p"/mangas?#{[q: "is:unread"]}")
      assert has_element?(index_live, "#mangas-#{manga.id}")
    end

    test "saves the default filter to the browser", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")

      {:ok, index_live, _html} = live(conn, ~p"/mangas")
      index_live |> element("#filter-toggle") |> render_click()

      index_live |> form("#filter-base-form", base: "-seinen -") |> render_submit()
      assert has_element?(index_live, "#filter-base-error")
      assert has_element?(index_live, "#mangas-#{manga.id}")

      index_live |> form("#filter-base-form", base: "-seinen -nosuchtag") |> render_submit()
      assert_push_event(index_live, "filter_base", %{value: "-seinen -nosuchtag"})
      refute has_element?(index_live, "#mangas-#{manga.id}")
      assert has_element?(index_live, "#filter-tags button[data-source=base]", "seinen")
      assert render(index_live) =~ "nosuchtag"

      index_live |> element("#filter-show-all") |> render_click()
      assert_patch(index_live, ~p"/mangas?all=1")
      assert has_element?(index_live, "#mangas-#{manga.id}")
    end

    test "keeps the filter when a manga is edited", %{conn: conn, manga: manga} do
      manga = tag_manga(manga, "seinen")
      {:ok, index_live, _html} = live(conn, ~p"/mangas?q=seinen")

      index_live |> element("#mangas-#{manga.id} a", "Edit") |> render_click()
      assert_patch(index_live, ~p"/mangas/#{manga}/edit")

      index_live |> form("#manga-form", manga: %{tags: "seinen"}) |> render_submit()
      assert_patch(index_live, ~p"/mangas?q=seinen")
    end

    test "deletes manga in listing", %{conn: conn, manga: manga} do
      {:ok, index_live, _html} = live(conn, ~p"/mangas")

      assert index_live |> element("#mangas-#{manga.id} a", "Edit") |> render_click() =~
               "Edit Manga"

      assert index_live |> element("#manga-form button", "Delete") |> render_click()
      refute has_element?(index_live, "#mangas-#{manga.id}")
    end

    test "deleting a manga keeps it for other followers", %{conn: conn, manga: manga, user: user} do
      other = MangaWatcher.AccountsFixtures.user_fixture()
      {:ok, _} = UserMangas.create_user_manga(%{manga_id: manga.id, user_id: other.id})

      {:ok, index_live, _html} = live(conn, ~p"/mangas/#{manga}/edit")
      index_live |> element("#manga-form button", "Delete") |> render_click()

      refute has_element?(index_live, "#mangas-#{manga.id}")
      assert_raise Ecto.NoResultsError, fn -> UserMangas.get_manga!(user.id, manga.id) end
      assert UserMangas.get_manga!(other.id, manga.id)
    end
  end
end
