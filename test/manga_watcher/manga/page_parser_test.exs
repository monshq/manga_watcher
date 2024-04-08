defmodule MangaWatcher.Manga.PageParserTest do
  alias MangaWatcher.Manga.PageParser
  alias MangaWatcher.Series.Website

  use ExUnit.Case, async: true

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

    test "correctly parses asuratoon page with chapter names in url" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/asuratoon2.html")

      website = %Website{
        title_regex: "h1.entry-title",
        links_regex: "#chapterlist a",
        preview_regex: ".thumbook img"
      }

      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture, website)

      assert parsed_attrs == %{
               last_chapter: 139,
               name: "Solo Max-Level Newbie",
               preview:
                 "https://img.asuracomics.com/unsafe/fit-in/720x936/https://asuratoon.com/wp-content/uploads/2021/07/solomaxlevelnewbie.jpg"
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
  end
end
