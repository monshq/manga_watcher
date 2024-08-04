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
  Generate a manga with user_manga association with user.
  """
  def manga_for_user_fixture(user, attrs \\ %{}) do
    manga = manga_fixture(attrs)

    {:ok, _user_manga} =
      MangaWatcher.UserMangas.create_user_manga(%{manga_id: manga.id, user_id: user.id})

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
