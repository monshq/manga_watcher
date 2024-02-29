defmodule MangaWatcher.Series do
  @moduledoc """
  The Series context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Repo

  require Logger

  # SOURCES

  # TAGS

  def list_tags() do
    Repo.all(Tag)
  end

  # MANGAS

  def list_mangas() do
    Manga
    |> order_by(desc: fragment("last_chapter - last_read_chapter"))
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def broken_asura_mangas() do
    Manga
    |> where(fragment("failed_updates > 5"))
    |> where(fragment("url ilike '%asura%'"))
    |> Repo.all()
  end

  def filter_mangas(include_tags, exclude_tags) do
    query =
      case include_tags do
        [] ->
          from m in Manga,
            left_join: t in assoc(m, :tags),
            where: is_nil(t.name) or t.name not in ^exclude_tags,
            group_by: m.id

        _ ->
          from m in Manga,
            left_join: t in assoc(m, :tags),
            where: is_nil(t.name) or t.name not in ^exclude_tags,
            where: t.name in ^include_tags,
            group_by: m.id
      end

    query
    |> order_by(desc: fragment("last_chapter - last_read_chapter"))
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def get_manga!(id) do
    Manga
    |> preload(:tags)
    |> Repo.get!(id)
  end

  def validate_new_manga(attrs \\ %{}) do
    Manga.pre_create_changeset(attrs)
  end

  def create_manga(attrs \\ %{}) do
    cs = Manga.pre_create_changeset(attrs)

    if cs.valid? do
      {:ok, parsed_attrs} = attrs |> Updater.parse_attrs()
      parsed_attrs = Map.put(parsed_attrs, :last_read_chapter, parsed_attrs.last_chapter)

      Manga.create_changeset(parsed_attrs)
      |> Repo.insert()
    else
      Repo.insert(cs)
    end
  end

  def update_manga(%Manga{} = manga, attrs) do
    manga
    |> Manga.update_changeset(attrs)
    |> Repo.update()
  end

  def refresh_all_manga() do
    list_mangas() |> Repo.preload(:tags) |> Updater.batch_update()
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
