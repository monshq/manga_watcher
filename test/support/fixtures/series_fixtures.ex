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
end
