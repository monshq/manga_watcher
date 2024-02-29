defmodule MangaWatcher.MangaSourcesTest do
  use MangaWatcher.DataCase

  alias MangaWatcher.MangaSources

  describe "websites" do
    alias MangaWatcher.MangaSources.Website

    import MangaWatcher.MangaSourcesFixtures

    @invalid_attrs %{base_url: nil, title_regex: nil, links_regex: nil}

    test "list_websites/0 returns all websites" do
      website = website_fixture()
      assert MangaSources.list_websites() == [website]
    end

    test "get_website!/1 returns the website with given id" do
      website = website_fixture()
      assert MangaSources.get_website!(website.id) == website
    end

    test "create_website/1 with valid data creates a website" do
      valid_attrs = %{base_url: "some base_url", title_regex: "some title_regex", links_regex: "some links_regex"}

      assert {:ok, %Website{} = website} = MangaSources.create_website(valid_attrs)
      assert website.base_url == "some base_url"
      assert website.title_regex == "some title_regex"
      assert website.links_regex == "some links_regex"
    end

    test "create_website/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MangaSources.create_website(@invalid_attrs)
    end

    test "update_website/2 with valid data updates the website" do
      website = website_fixture()
      update_attrs = %{base_url: "some updated base_url", title_regex: "some updated title_regex", links_regex: "some updated links_regex"}

      assert {:ok, %Website{} = website} = MangaSources.update_website(website, update_attrs)
      assert website.base_url == "some updated base_url"
      assert website.title_regex == "some updated title_regex"
      assert website.links_regex == "some updated links_regex"
    end

    test "update_website/2 with invalid data returns error changeset" do
      website = website_fixture()
      assert {:error, %Ecto.Changeset{}} = MangaSources.update_website(website, @invalid_attrs)
      assert website == MangaSources.get_website!(website.id)
    end

    test "delete_website/1 deletes the website" do
      website = website_fixture()
      assert {:ok, %Website{}} = MangaSources.delete_website(website)
      assert_raise Ecto.NoResultsError, fn -> MangaSources.get_website!(website.id) end
    end

    test "change_website/1 returns a website changeset" do
      website = website_fixture()
      assert %Ecto.Changeset{} = MangaSources.change_website(website)
    end
  end
end
