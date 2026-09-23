defmodule MangaWatcher.Manga.PageParserTest do
  use ExUnit.Case, async: true

  alias MangaWatcher.Manga.PageParser
  alias MangaWatcher.Series.Website

  describe "parse/1" do
    test "correctly parses asuratoon page" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/asuratoon.html")

      website = %Website{
        title_regex: "h1.entry-title",
        links_regex: "#chapterlist a",
        preview_regex: ".thumbook img"
      }

      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture, website)

      assert parsed_attrs == %{
               last_chapter: 81,
               name: "Academy’s Undercover Professor",
               preview:
                 "https://img.asuracomics.com/unsafe/fit-in/720x936/https://asuratoon.com/wp-content/uploads/2022/06/Academys_Undercover_ProfessorCover_copy.png"
             }
    end

    test "correctly parses manhwalike page" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/manhwalike.html")

      website = %Website{
        title_regex: ".main-head h1",
        links_regex: ".chapter-list a",
        preview_regex: "figure.cover img"
      }

      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture, website)

      assert parsed_attrs == %{
               last_chapter: 260,
               name: "Skeleton Soldier Couldn’t Protect the Dungeon",
               preview:
                 "https://stmedia.manhwalike.com/images/thumbs/skeleton-soldier-couldnt-protect-the-dungeon.jpg"
             }
    end

    test "correctly parses batoto page with chapters in link text" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/batoto.html")

      website = %Website{
        title_regex: ".item-title a",
        links_regex: ".episode-list .main a",
        preview_regex: ".detail-set img"
      }

      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture, website)

      assert parsed_attrs == %{
               last_chapter: 311,
               name: "The Skeleton Soldier Failed to Defend the Dungeon (Official)",
               preview:
                 "https://b02.mbhiz.org/thumb/W600/ampi/f37/f376200d676daf9606382f16d82cb6695b553aad_420_610_135239.jpeg"
             }
    end
  end

  describe "parse/2 preview" do
    defp preview_for(html, selector) do
      page = "<h1>Name</h1><a href='/chapter-1'>1</a>#{html}"

      website = %Website{
        base_url: "site.com",
        title_regex: "h1",
        links_regex: "a",
        preview_regex: selector
      }

      {:ok, %{preview: preview}} = PageParser.parse(page, website)
      preview
    end

    test "falls back to lazy-load attributes when src is a placeholder" do
      html =
        ~s(<img class="cover" src="data:image/gif;base64,R0lGOD" data-src="https://cdn.site.com/c.jpg">)

      assert preview_for(html, "img.cover") == "https://cdn.site.com/c.jpg"
    end

    test "reads og:image meta content" do
      html = ~s(<meta property="og:image" content="https://cdn.site.com/og.jpg">)
      assert preview_for(html, ~s(meta[property="og:image"])) == "https://cdn.site.com/og.jpg"
    end

    test "normalizes relative and protocol-relative urls" do
      assert preview_for(~s(<img src="/c.jpg">), "img") == "http://site.com/c.jpg"

      assert preview_for(~s(<img src="//cdn.site.com/c.jpg">), "img") ==
               "https://cdn.site.com/c.jpg"
    end
  end

  describe "diagnose/2" do
    test "reports matches of working selectors" do
      page = File.read!("test/support/fixtures/website_pages/asuratoon.html")

      website = %Website{
        base_url: "asuratoon.com",
        title_regex: "h1.entry-title",
        links_regex: "#chapterlist a",
        preview_regex: ".thumbook img"
      }

      assert %{title: title, links: links, preview: preview} = PageParser.diagnose(page, website)

      assert title.matches == 1
      assert title.value == "Academy’s Undercover Professor"
      assert links.max_chapter == 81
      assert links.with_chapter > 0
      assert [%{chapter: 81, href: href} | _] = links.samples
      assert href =~ "chapter-81"
      assert preview.matches == 1
      assert preview.url =~ "Academys_Undercover_ProfessorCover_copy.png"
    end

    test "reports problems of bad selectors instead of failing" do
      page = """
      <h2 class="t">One</h2><h2 class="t">Two</h2>
      <nav><a href="/home">Home</a><a href="/list">List</a></nav>
      """

      website = %Website{title_regex: "h2.t", links_regex: "nav a", preview_regex: "img.cover"}

      assert %{title: title, links: links, preview: preview} = PageParser.diagnose(page, website)

      assert title == %{matches: 2, value: nil, samples: ["One", "Two"]}
      assert %{matches: 2, with_chapter: 0, max_chapter: nil} = links
      assert [%{chapter: nil, href: "/home", text: "Home"} | _] = links.samples
      assert preview == %{matches: 0, url: nil}
    end
  end
end
