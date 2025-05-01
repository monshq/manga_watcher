defmodule MangaWatcher.UserMangas do
  @moduledoc """
  The UserMangas context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series.UserManga
  alias MangaWatcher.Repo

  require Logger

  def create_user_manga(attrs) do
    attrs |> UserManga.create_changeset() |> Repo.insert()
  end

  def list_mangas(user_id) do
    query =
      from m in Manga,
        join: um in assoc(m, :user_mangas),
        where: um.user_id == ^user_id,
        order_by: [desc: m.last_chapter - um.last_read_chapter, desc: m.updated_at],
        preload: :user_mangas

    Repo.all(query)
  end

  def filter_mangas(user_id, include_tags, exclude_tags) do
    exclude_query =
      from m in Manga,
        join: t in assoc(m, :tags),
        where: t.name in ^exclude_tags,
        select: m.id

    query =
      from m in Manga,
        join: um in assoc(m, :user_mangas),
        where: um.user_id == ^user_id,
        where: m.id not in subquery(exclude_query),
        left_join: t in assoc(m, :tags),
        where: fragment("cardinality(?::text[]) = 0", ^include_tags) or t.name in ^include_tags,
        group_by: [m.id, um.last_read_chapter],
        order_by: [desc: m.last_chapter - um.last_read_chapter, desc: :updated_at],
        preload: :user_mangas

    Repo.all(query)
  end

  def get_manga!(user_id, id) do
    query =
      from m in Manga,
        left_join: t in assoc(m, :tags),
        join: um in assoc(m, :user_mangas),
        where: um.user_id == ^user_id,
        where: m.id == ^id,
        preload: [tags: t, user_mangas: um]

    Repo.one!(query)
  end

  def update_user_manga(%UserManga{} = user_manga, attrs) do
    user_manga
    |> UserManga.changeset(attrs)
    |> Repo.update()
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
