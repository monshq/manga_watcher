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
        last_chapter: 42,
        last_read_chapter: 42,
        name: "some name",
        url: "some url"
      })
      |> MangaWatcher.Series.create_manga()

    manga
  end
end
