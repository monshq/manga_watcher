defmodule MangaWatcher.Series do
  @moduledoc """
  The Series context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series.Website
  alias MangaWatcher.Manga.Updater
  alias MangaWatcher.Repo

  require Logger

  # SOURCES

  def list_websites do
    Repo.all(Website)
  end

  def website_counts do
    query =
      from w in Website,
        left_join: m in Manga,
        on: like(m.url, fragment("'%' || ? || '%'", w.base_url)),
        left_join: t in assoc(m, :tags),
        group_by: w.id,
        select: %{
          id: w.id,
          total: count(m.id, :distinct),
          broken: fragment("COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)", t.name, "broken", m.id)
        }

    Repo.all(query)
    |> Enum.into(%{}, fn map ->
      {map.id, Map.delete(map, :id)}
    end)
  end

  def get_website!(id), do: Repo.get!(Website, id)

  def get_website_for_url(url) do
    uri = URI.parse(url)

    website =
      Website
      |> where(base_url: ^uri.host)
      |> Repo.one!()

    {:ok, website}
  rescue
    e ->
      host = URI.parse(url).host
      Logger.warning("could not get parser for website #{host}: #{inspect(e)}")
      {:error, "could not get parser for website #{host}"}
  end

  def create_website(attrs \\ %{}) do
    %Website{}
    |> Website.changeset(attrs)
    |> Repo.insert()
  end

  def update_website(%Website{} = website, attrs) do
    website
    |> Website.changeset(attrs)
    |> Repo.update()
  end

  def change_website(%Website{} = website, attrs \\ %{}) do
    Website.changeset(website, attrs)
  end

  def delete_website(%Website{} = website) do
    Repo.delete(website)
  end

  # TAGS

  def list_tags() do
    Repo.all(Tag)
  end

  # MANGAS

  def add_manga_tag(manga, tag_name) do
    tag =
      case Repo.get_by(Tag, name: tag_name) do
        nil -> %{name: tag_name}
        tag -> tag
      end

    Manga.add_tag(manga, tag) |> Repo.update()
  end

  def remove_manga_tag(manga, tag_name) do
    Manga.remove_tag(manga, tag_name) |> Repo.update()
  end

  def list_mangas() do
    Repo.all(Manga)
  end

  def list_mangas_for_update() do
    query =
      from m in Manga,
        left_join: t in assoc(m, :tags),
        on: t.name in ["broken", "completed"],
        where: is_nil(t.id),
        group_by: m.id

    Repo.all(query)
  end

  # def filter_mangas(include_tags, exclude_tags) do
  #   exclude_query =
  #     from m in Manga,
  #       join: t in assoc(m, :tags),
  #       where: t.name in ^exclude_tags,
  #       select: m.id
  #
  #   common_query =
  #     from m in Manga,
  #       join: um in assoc(m, :user_mangas),
  #       where: m.id not in subquery(exclude_query),
  #       group_by: [m.id, um.last_read_chapter],
  #       order_by: [desc: m.last_chapter - um.last_read_chapter, desc: :updated_at],
  #       preload: :user_mangas
  #
  #   query =
  #     case include_tags do
  #       [] ->
  #         from m in common_query,
  #           left_join: t in assoc(m, :tags)
  #
  #       _ ->
  #         from m in common_query,
  #           left_join: t in assoc(m, :tags),
  #           where: t.name in ^include_tags
  #     end
  #
  #   Repo.all(query)
  # end

  def broken_asura_mangas() do
    Manga
    |> where(fragment("failed_updates > 5"))
    |> where(fragment("url ilike '%asura%'"))
    |> Repo.all()
  end

  def get_manga(attrs) do
    Manga
    |> preload([:tags, :user_mangas])
    |> Repo.get_by(attrs)
  end

  def get_manga!(id) do
    Manga
    |> preload([:tags, :user_mangas])
    |> Repo.get!(id)
  end

  def validate_new_manga(attrs \\ %{}) do
    Manga.pre_create_changeset(attrs)
  end

  def create_manga(attrs \\ %{}) do
    cs = Manga.pre_create_changeset(attrs)

    if cs.valid? do
      {:ok, parsed_attrs} = attrs |> Updater.parse_attrs()

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
    list_mangas_for_update() |> Repo.preload(:tags) |> Updater.batch_update()
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
