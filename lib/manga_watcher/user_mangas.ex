defmodule MangaWatcher.UserMangas do
  @moduledoc """
  The UserMangas context.
  """

  import Ecto.Query, warn: false

  alias MangaWatcher.Series
  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Series.UserManga
  alias MangaWatcher.Repo

  @dormant_after [month: -1]
  @dormant_tag "dormant"

  def dormant_tag, do: @dormant_tag

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

  @doc """
  With a `UserManga`: the user hasn't read the manga for over a month.

  With a `Manga`: it has unread chapters for every user following it and none of
  them read it for over a month. A manga nobody follows is never dormant.
  """
  def dormant?(%UserManga{last_read_at: last_read_at}) do
    NaiveDateTime.before?(last_read_at, dormant_cutoff())
  end

  def dormant?(%Manga{} = manga) do
    %Manga{user_mangas: user_mangas} = load_user_mangas(manga)
    user_mangas != [] and Enum.all?(user_mangas, &dormant_for_user?(manga, &1))
  end

  defp dormant_for_user?(%Manga{last_chapter: last_chapter}, %UserManga{} = user_manga) do
    user_manga.last_read_chapter < last_chapter and dormant?(user_manga)
  end

  def dormant_cutoff do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.shift(@dormant_after)
    |> NaiveDateTime.truncate(:second)
  end

  def load_user_mangas(%Manga{user_mangas: user_mangas} = manga) when is_list(user_mangas),
    do: manga

  def load_user_mangas(%Manga{} = manga), do: Repo.preload(manga, :user_mangas)

  def update_user_manga(%UserManga{} = user_manga, attrs) do
    with {:ok, user_manga} <- user_manga |> UserManga.changeset(attrs) |> Repo.update() do
      unmark_dormant_if_active(user_manga)
      {:ok, user_manga}
    end
  end

  # the updater only visits dormant mangas once a day, so drop the tag right away
  # once the user catches up instead of waiting for the next poll
  defp unmark_dormant_if_active(%UserManga{} = user_manga) do
    manga = Repo.preload(user_manga, manga: :user_mangas).manga

    unless dormant?(manga) do
      {:ok, _} = Series.remove_manga_tag(manga, @dormant_tag)
    end
  end

  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
