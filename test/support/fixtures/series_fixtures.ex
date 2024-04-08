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
        url: "http://mangasource.com/qwerty"
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
        base_url: "http://mangasource.com",
        links_regex: "#chapterlist a",
        title_regex: "h1.entry-title",
        preview_regex: ".thumbook img"
      })
      |> MangaWatcher.Series.create_website()

    website
  end
end
