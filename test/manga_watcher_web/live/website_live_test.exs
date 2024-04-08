# defmodule MangaWatcherWeb.WebsiteLiveTest do
#   use MangaWatcherWeb.ConnCase
#
#   import Phoenix.LiveViewTest
#   import MangaWatcher.SeriesFixtures
#
#   @create_attrs %{
#     base_url: "some base_url",
#     title_regex: "some title_regex",
#     links_regex: "some links_regex",
#     preview_regex: "some preview_regex"
#   }
#   @update_attrs %{
#     base_url: "some updated base_url",
#     title_regex: "some updated title_regex",
#     links_regex: "some updated links_regex",
#     preview_regex: "some updated preview_regex"
#   }
#   @invalid_attrs %{base_url: nil, title_regex: nil, links_regex: nil, preview_regex: nil}
#
#   defp create_website(_) do
#     website = website_fixture()
#     %{website: website}
#   end
#
#   describe "Index" do
#     setup [:create_website]
#
#     test "lists all websites", %{conn: conn, website: website} do
#       {:ok, _index_live, html} = live(conn, ~p"/websites")
#
#       assert html =~ "Listing Websites"
#       assert html =~ website.base_url
#     end
#
#     test "saves new website", %{conn: conn} do
#       {:ok, index_live, _html} = live(conn, ~p"/websites")
#
#       assert index_live |> element("a", "New Website") |> render_click() =~
#                "New Website"
#
#       assert_patch(index_live, ~p"/websites/new")
#
#       assert index_live
#              |> form("#website-form", website: @invalid_attrs)
#              |> render_change() =~ "can&#39;t be blank"
#
#       assert index_live
#              |> form("#website-form", website: @create_attrs)
#              |> render_submit()
#
#       assert_patch(index_live, ~p"/websites")
#
#       html = render(index_live)
#       assert html =~ "Website created successfully"
#       assert html =~ "some base_url"
#     end
#
#     test "updates website in listing", %{conn: conn, website: website} do
#       {:ok, index_live, _html} = live(conn, ~p"/websites")
#
#       assert index_live |> element("#websites-#{website.id} a", "Edit") |> render_click() =~
#                "Edit Website"
#
#       assert_patch(index_live, ~p"/websites/#{website}/edit")
#
#       assert index_live
#              |> form("#website-form", website: @invalid_attrs)
#              |> render_change() =~ "can&#39;t be blank"
#
#       assert index_live
#              |> form("#website-form", website: @update_attrs)
#              |> render_submit()
#
#       assert_patch(index_live, ~p"/websites")
#
#       html = render(index_live)
#       assert html =~ "Website updated successfully"
#       assert html =~ "some updated base_url"
#     end
#
#     test "deletes website in listing", %{conn: conn, website: website} do
#       {:ok, index_live, _html} = live(conn, ~p"/websites")
#
#       assert index_live |> element("#websites-#{website.id} a", "Delete") |> render_click()
#       refute has_element?(index_live, "#websites-#{website.id}")
#     end
#   end
#
#   describe "Show" do
#     setup [:create_website]
#
#     test "displays website", %{conn: conn, website: website} do
#       {:ok, _show_live, html} = live(conn, ~p"/websites/#{website}")
#
#       assert html =~ "Show Website"
#       assert html =~ website.base_url
#     end
#
#     test "updates website within modal", %{conn: conn, website: website} do
#       {:ok, show_live, _html} = live(conn, ~p"/websites/#{website}")
#
#       assert show_live |> element("a", "Edit") |> render_click() =~
#                "Edit Website"
#
#       assert_patch(show_live, ~p"/websites/#{website}/show/edit")
#
#       assert show_live
#              |> form("#website-form", website: @invalid_attrs)
#              |> render_change() =~ "can&#39;t be blank"
#
#       assert show_live
#              |> form("#website-form", website: @update_attrs)
#              |> render_submit()
#
#       assert_patch(show_live, ~p"/websites/#{website}")
#
#       html = render(show_live)
#       assert html =~ "Website updated successfully"
#       assert html =~ "some updated base_url"
#     end
#   end
# end
