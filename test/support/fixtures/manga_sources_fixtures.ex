defmodule MangaWatcher.MangaSourcesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MangaWatcher.MangaSources` context.
  """

  @doc """
  Generate a website.
  """
  def website_fixture(attrs \\ %{}) do
    {:ok, website} =
      attrs
      |> Enum.into(%{
        base_url: "some base_url",
        links_regex: "some links_regex",
        title_regex: "some title_regex"
      })
      |> MangaWatcher.MangaSources.create_website()

    website
  end
end
