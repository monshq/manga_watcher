defmodule MangaWatcher.UserMangas do
  @moduledoc """
  The UserMangas context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Series.UserManga
  alias MangaWatcher.Repo

  @dormant_after [month: -1]
  @dormant_tag "dormant"

  @type state :: :broken | :read | :unread | :dormant

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

  @doc """
  Reading state of a manga for the user whose `user_mangas` record is preloaded.

    * `:broken`  - updates keep failing
    * `:read`    - no unread chapters
    * `:dormant` - has unread chapters, but wasn't read for over a month
    * `:unread`  - has unread chapters
  """
  @spec manga_state(Manga.t()) :: state()
  def manga_state(%Manga{user_mangas: [%UserManga{} = user_manga | _]} = manga) do
    cond do
      manga.failed_updates > 5 -> :broken
      manga.last_chapter <= user_manga.last_read_chapter -> :read
      dormant?(user_manga) -> :dormant
      true -> :unread
    end
  end

  def dormant?(%UserManga{last_read_at: last_read_at}) do
    NaiveDateTime.before?(last_read_at, dormant_cutoff())
  end

  def dormant_cutoff do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.shift(@dormant_after)
    |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Adds the "#{@dormant_tag}" tag to mangas that are dormant for every user following
  them and removes it from all other mangas.

  Pass a manga id to sync only that manga. Returns the number of added and removed tags.
  """
  @spec sync_dormant_tags(integer() | nil) :: %{
          added: non_neg_integer(),
          removed: non_neg_integer()
        }
  def sync_dormant_tags(manga_id \\ nil) do
    tag = dormant_tag()
    cutoff = dormant_cutoff()

    # user_mangas that are either fully read or were read recently
    active_query =
      from um in UserManga,
        join: m in assoc(um, :manga),
        where: um.last_read_chapter >= m.last_chapter or um.last_read_at >= ^cutoff,
        select: um.manga_id

    dormant_query =
      from um in UserManga,
        where: um.manga_id not in subquery(active_query),
        distinct: true

    dormant_ids_query = select(dormant_query, [um], um.manga_id)

    insert_query =
      dormant_query
      |> scope_to_manga(manga_id)
      |> select([um], %{manga_id: um.manga_id, tag_id: type(^tag.id, :integer)})

    untag_query =
      from mt in "manga_tags",
        where: mt.tag_id == ^tag.id,
        where: mt.manga_id not in subquery(dormant_ids_query)

    {added, _} = Repo.insert_all("manga_tags", insert_query, on_conflict: :nothing)
    {removed, _} = Repo.delete_all(scope_to_manga(untag_query, manga_id))

    %{added: added, removed: removed}
  end

  defp scope_to_manga(query, nil), do: query
  defp scope_to_manga(query, manga_id), do: from(q in query, where: q.manga_id == ^manga_id)

  defp dormant_tag do
    Repo.get_by(Tag, name: @dormant_tag) || Repo.insert!(%Tag{name: @dormant_tag})
  end

  def update_user_manga(%UserManga{} = user_manga, attrs) do
    result =
      user_manga
      |> UserManga.changeset(attrs)
      |> Repo.update()

    with {:ok, %UserManga{manga_id: manga_id}} <- result do
      sync_dormant_tags(manga_id)
      result
    end
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
