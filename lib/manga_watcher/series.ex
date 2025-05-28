defmodule MangaWatcher.Series do
  @moduledoc """
  The Series context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series.Website
  alias MangaWatcher.Repo

  require Logger

  @update_duration %{
    normal: %{hour: -1},
    stale: %{hour: -24}
  }

  # SOURCES

  def list_websites do
    query =
      from w in Website,
        left_join: m in Manga,
        on: like(m.url, fragment("'%' || ? || '%'", w.base_url)),
        group_by: w.id,
        order_by: [desc: count(m)]

    Repo.all(query)
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
          broken: fragment("COUNT(DISTINCT ?) FILTER (WHERE ? = ?)", m.id, t.name, "broken")
        }

    Repo.all(query)
    |> Enum.into(%{}, fn map ->
      {map.id, Map.delete(map, :id)}
    end)
  end

  def get_website!(id), do: Repo.get!(Website, id)

  def get_website_for_url(url) do
    uri = URI.parse(url)

    if is_nil(uri.host) do
      {:error, "website host is empty"}
    else
      case Repo.one(from w in Website, where: w.base_url == ^uri.host) do
        nil ->
          Logger.warning("no parser for website #{uri.host}")
          {:error, "no parser for website #{uri.host}"}

        website ->
          {:ok, website}
      end
    end
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

  def manga_has_tag?(manga, tag) do
    tag_names = load_manga_tags(manga).tags |> Enum.map(& &1.name)
    tag in tag_names
  end

  def load_manga_tags(%Manga{tags: tags} = manga) when is_list(tags), do: manga

  def load_manga_tags(%Manga{} = manga), do: Repo.preload(manga, :tags)

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
    exclude_ids_query =
      from m in Manga,
        join: t in assoc(m, :tags),
        where: t.name in ["broken", "completed"],
        select: m.id,
        distinct: true

    stale_manga_ids_query =
      from m in Manga,
        join: t in assoc(m, :tags),
        where: t.name in ["stale", "slow-burner"],
        select: m.id,
        distinct: true

    stale_cutoff = NaiveDateTime.shift(NaiveDateTime.utc_now(), @update_duration.stale)
    normal_cutoff = NaiveDateTime.shift(NaiveDateTime.utc_now(), @update_duration.normal)

    query =
      from m in Manga,
        where: m.id not in subquery(exclude_ids_query),
        where:
          (m.id in subquery(stale_manga_ids_query) and m.updated_at < ^stale_cutoff) or
            (m.id not in subquery(stale_manga_ids_query) and m.updated_at < ^normal_cutoff),
        preload: :tags

    Repo.all(query)
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
    attrs
    |> Manga.create_changeset()
    |> Repo.insert()
  end

  def update_manga(%Manga{} = manga, attrs, opts \\ []) do
    manga
    |> Manga.update_changeset(attrs)
    |> Repo.update(opts)
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
