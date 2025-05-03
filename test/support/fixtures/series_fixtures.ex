defmodule MangaWatcher.SeriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MangaWatcher.Series` context
  or doing raw inserts.
  """

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series
  alias MangaWatcher.UserMangas
  alias MangaWatcher.Repo

  def default_manga_attrs() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    id = System.unique_integer([:positive, :monotonic])

    %{
      name: "Fixture Manga",
      url: "http://mangasource.com/#{id}",
      preview: nil,
      last_chapter: 1,
      last_chapter_updated_at: now,
      failed_updates: 0
    }
  end

  @doc """
  Generate a manga.
  """
  def manga_fixture(attrs \\ %{}) do
    attrs = Map.merge(default_manga_attrs(), attrs)

    {:ok, manga} =
      MangaWatcher.Series.create_manga(attrs)

    manga
  end

  @doc """
  Generate a manga without validations.
  """
  def manga_raw_fixture(attrs \\ %{}) do
    attrs = Map.merge(default_manga_attrs(), attrs)

    struct(Manga, attrs) |> Repo.insert!()
  end

  def manga_fixture_with_tags(attrs \\ %{}) do
    manga = manga_raw_fixture(attrs |> Map.delete(:tags))

    for t <- attrs[:tags] do
      {:ok, _updated_manga} = Series.add_manga_tag(manga, t)
    end

    manga
  end

  @doc """
  Generate a manga with user_manga association with user.
  """
  def manga_for_user_fixture(user, original_attrs \\ %{}) do
    attrs = Map.merge(default_manga_attrs(), original_attrs |> Map.delete(:user_manga))
    {:ok, manga} = Series.create_manga(attrs)

    default_user_manga_attrs = %{manga_id: manga.id, user_id: user.id}
    user_manga_attrs = Map.merge(default_user_manga_attrs, original_attrs[:user_manga] || %{})
    {:ok, _user_manga} = UserMangas.create_user_manga(user_manga_attrs)

    manga
  end

  @doc """
  Generate a website.
  """
  def website_fixture(attrs \\ %{}) do
    id = System.unique_integer([:positive, :monotonic])

    {:ok, website} =
      attrs
      |> Enum.into(%{
        base_url: "mangasource#{id}.com",
        links_regex: "#chapterlist a",
        title_regex: "h1.entry-title",
        preview_regex: ".thumbook img"
      })
      |> MangaWatcher.Series.create_website()

    website
  end
end
