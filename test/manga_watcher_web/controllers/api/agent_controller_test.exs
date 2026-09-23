defmodule MangaWatcherWeb.Api.AgentControllerTest do
  use MangaWatcherWeb.ConnCase, async: true

  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.Series

  # MangaWatcher.Fake.Downloader serves the asuratoon fixture for every page
  @selectors %{
    "title" => "h1.entry-title",
    "links" => "#chapterlist a",
    "preview" => ".thumbook img"
  }
  @urls ["https://asuratoon.com/manga/a", "https://asuratoon.com/manga/b"]

  test "GET /api/agent/sources lists sources", %{conn: conn} do
    website_fixture(base_url: "asuratoon.com")

    assert %{"sources" => [%{"host" => "asuratoon.com", "mangas" => 0, "broken" => 0}]} =
             conn |> get(~p"/api/agent/sources") |> json_response(200)
  end

  describe "POST /api/agent/probe" do
    test "returns the verdict and html", %{conn: conn} do
      resp = conn |> post(~p"/api/agent/probe", %{url: hd(@urls)}) |> json_response(200)

      assert %{"verdict" => "ok", "host" => "asuratoon.com", "existing_source" => nil} = resp
      assert resp["html"] =~ "chapterlist"
    end

    test "requires url", %{conn: conn} do
      assert %{"error" => _} = conn |> post(~p"/api/agent/probe", %{}) |> json_response(400)
    end
  end

  describe "POST /api/agent/test" do
    test "returns a report per url", %{conn: conn} do
      resp =
        conn
        |> post(~p"/api/agent/test", %{urls: @urls, selectors: @selectors})
        |> json_response(200)

      assert %{"ok" => true, "reports" => [report, _]} = resp
      assert report["title"]["value"] == "Academy’s Undercover Professor"
      assert report["links"]["max_chapter"] == 81
    end

    test "validates params", %{conn: conn} do
      assert conn
             |> post(~p"/api/agent/test", %{urls: @urls, selectors: %{"title" => "h1"}})
             |> json_response(400)

      assert conn
             |> post(~p"/api/agent/test", %{urls: [], selectors: @selectors})
             |> json_response(400)
    end
  end

  describe "PUT /api/agent/sources/:host" do
    test "creates a new source", %{conn: conn} do
      resp =
        conn
        |> put(~p"/api/agent/sources/asuratoon.com", %{
          selectors: @selectors,
          verified_urls: @urls
        })
        |> json_response(201)

      assert %{"action" => "created", "source" => %{"host" => "asuratoon.com"}} = resp
      assert Series.get_website_by_host("asuratoon.com")
    end

    test "returns reports when selectors fail", %{conn: conn} do
      selectors = %{@selectors | "title" => "h2"}

      assert %{"reports" => [%{"ok" => false} | _]} =
               conn
               |> put(~p"/api/agent/sources/asuratoon.com", %{
                 selectors: selectors,
                 verified_urls: @urls
               })
               |> json_response(422)
    end

    test "requires confirmation to update an existing source", %{conn: conn} do
      website_fixture(base_url: "asuratoon.com", title_regex: "h1.old")
      params = %{selectors: @selectors, verified_urls: @urls}

      assert %{"current" => %{"title" => "h1.old"}, "proposed" => @selectors} =
               conn |> put(~p"/api/agent/sources/asuratoon.com", params) |> json_response(409)

      assert %{"action" => "updated"} =
               conn
               |> put(~p"/api/agent/sources/asuratoon.com", Map.put(params, :confirm, true))
               |> json_response(200)

      assert Series.get_website_by_host("asuratoon.com").title_regex == "h1.entry-title"
    end

    test "rejects too few verified urls", %{conn: conn} do
      assert %{"error" => error} =
               conn
               |> put(~p"/api/agent/sources/asuratoon.com", %{
                 selectors: @selectors,
                 verified_urls: [hd(@urls)]
               })
               |> json_response(400)

      assert error =~ "at least 2"
    end
  end
end
