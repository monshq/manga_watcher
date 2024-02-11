defmodule MangaWatcher.Manga.PageParserTest do
  alias MangaWatcher.Manga.PageParser

  use ExUnit.Case, async: true

  describe "parse/1" do
    test "correctly parses asuratoon page" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/asuratoon.html")
      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture)
      assert parsed_attrs == %{last_chapter: 81, name: "Academy’s Undercover Professor"}
    end

    test "correctly parses asuratoon page with chapter names in url" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/asuratoon2.html")
      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture)
      assert parsed_attrs == %{last_chapter: 139, name: "Solo Max-Level Newbie"}
    end

    test "correctly parses manhwalike page" do
      webpage_fixture = File.read!("test/support/fixtures/website_pages/manhwalike.html")
      {:ok, parsed_attrs} = PageParser.parse(webpage_fixture)

      assert parsed_attrs == %{
               last_chapter: 260,
               name: "Skeleton Soldier Couldn’t Protect the Dungeon"
             }
    end
  end
end
