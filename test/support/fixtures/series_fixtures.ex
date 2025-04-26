defmodule MangaWatcher.SeriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MangaWatcher.Series` context
  or doing raw inserts.
  """

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Repo

  @doc """
  Generate a manga.
  """
  def manga_fixture(attrs \\ %{}) do
    now = NaiveDateTime.local_now()

    default_attrs = %{
      name: "Fixture Manga",
      url: "http://mangasource.com/qwerty",
      preview: nil,
      last_chapter: 1,
      last_chapter_updated_at: now,
      failed_updates: 0
    }

    attrs = Map.merge(default_attrs, attrs)

    struct(Manga, attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a manga with user_manga association with user.
  """
  def manga_for_user_fixture(user, attrs \\ %{}) do
    {:ok, manga} =
      attrs
      |> Enum.into(%{
        url: "http://mangasource.com/qwerty"
      })
      |> MangaWatcher.Series.create_manga()

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
        base_url: "mangasource.com",
        links_regex: "#chapterlist a",
        title_regex: "h1.entry-title",
        preview_regex: ".thumbook img"
      })
      |> MangaWatcher.Series.create_website()

    website
  end
end
