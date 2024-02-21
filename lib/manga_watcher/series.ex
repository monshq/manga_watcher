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

  @doc """
  Returns the list of mangas.

  ## Examples

      iex> list_mangas()
      [%Manga{}, ...]

  """
  def list_mangas() do
    Manga
    |> order_by(desc: fragment("last_chapter - last_read_chapter"))
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def list_tags() do
    Repo.all(Tag)
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

  @doc """
  Gets a single manga.

  Raises `Ecto.NoResultsError` if the Manga does not exist.

  ## Examples

      iex> get_manga!(123)
      %Manga{}

      iex> get_manga!(456)
      ** (Ecto.NoResultsError)

  """
  def get_manga!(id) do
    Manga
    |> preload(:tags)
    |> Repo.get!(id)
  end

  def validate_new_manga(attrs \\ %{}) do
    Manga.pre_create_changeset(attrs)
  end

  @doc """
  Creates a manga.

  ## Examples

      iex> create_manga(%{field: value})
      {:ok, %Manga{}}

      iex> create_manga(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
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

  @doc """
  Updates a manga.

  ## Examples

      iex> update_manga(manga, %{field: new_value})
      {:ok, %Manga{}}

      iex> update_manga(manga, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_manga(%Manga{} = manga, attrs) do
    manga
    |> Manga.update_changeset(attrs)
    |> Repo.update()
  end

  def refresh_all_manga() do
    list_mangas() |> Repo.preload(:tags) |> Updater.batch_update()
  end

  @doc """
  Deletes a manga.

  ## Examples

      iex> delete_manga(manga)
      {:ok, %Manga{}}

      iex> delete_manga(manga)
      {:error, %Ecto.Changeset{}}

  """
  def delete_manga(%Manga{} = manga) do
    Repo.delete(manga)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking manga changes.

  ## Examples

      iex> change_manga(manga)
      %Ecto.Changeset{data: %Manga{}}

  """
  def change_manga(%Manga{} = manga, attrs \\ %{}) do
    Manga.pre_update_changeset(manga, attrs)
  end
end
