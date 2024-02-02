defmodule MangaWatcher.Series do
  @moduledoc """
  The Series context.
  """

  import Ecto.Query, warn: false
  alias MangaWatcher.Manga.PageParser
  alias MangaWatcher.Repo

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Utils

  require Logger

  @downloader Application.compile_env(:manga_watcher, :page_downloader)

  @doc """
  Returns the list of mangas.

  ## Examples

      iex> list_mangas()
      [%Manga{}, ...]

  """
  def list_mangas do
    Manga
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
  def get_manga!(id), do: Repo.get!(Manga, id)

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
      parsed_attrs = attrs |> Utils.atomize_keys() |> parse_attrs()
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
    Logger.info("starting update of all mangas")

    Enum.each(list_mangas(), fn manga ->
      parsed_attrs = manga |> Map.from_struct() |> parse_attrs()
      {:ok, _} = update_manga(manga, parsed_attrs)
    end)

    Logger.info("finished updating mangas")
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
    Manga.update_changeset(manga, attrs)
  end

  def parse_attrs(manga_attrs) when is_binary(manga_attrs.url) do
    with {:ok, html_content} <- @downloader.download(manga_attrs.url),
         {:ok, attrs} <- PageParser.parse(html_content) do
      Logger.info("successfully parsed manga #{manga_attrs.url}: #{inspect(attrs)}")
      Map.merge(manga_attrs, attrs)
    else
      {:error, reason} ->
        Logger.error("could not parse manga #{manga_attrs.url}: #{inspect(reason)}")
        manga_attrs
    end
  end

  def parse_attrs(manga_attrs), do: manga_attrs
end
