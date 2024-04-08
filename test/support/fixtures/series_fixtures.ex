defmodule MangaWatcher.SeriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MangaWatcher.Series` context.
  """

  @doc """
  Generate a manga.
  """
  def manga_fixture(attrs \\ %{}) do
    {:ok, manga} =
      attrs
      |> Enum.into(%{
        url: "asdf.com/qwerty"
      })
      |> MangaWatcher.Series.create_manga()

    manga
  end

  @doc """
  Generate a website.
  """
  def website_fixture(attrs \\ %{}) do
    {:ok, website} =
      attrs
      |> Enum.into(%{
        base_url: "some base_url",
        links_regex: "some links_regex",
        title_regex: "some title_regex",
        preview_regex: "some preview_regex"
      })
      |> MangaWatcher.Series.create_website()

    website
  end
end
