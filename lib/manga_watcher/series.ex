defmodule MangaWatcher.Series do
  @moduledoc """
  The Series context.
  """

  import Ecto.Query, warn: false
  alias MangaWatcher.Repo

  alias MangaWatcher.Series.Manga

  require Logger

  @doc """
  Returns the list of mangas.

  ## Examples

      iex> list_mangas()
      [%Manga{}, ...]

  """
  def list_mangas do
    Manga |> order_by(desc: fragment("last_chapter - last_read_chapter")) |> Repo.all()
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

  @doc """
  Creates a manga.

  ## Examples

      iex> create_manga(%{field: value})
      {:ok, %Manga{}}

      iex> create_manga(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_manga(attrs \\ %{}) do
    %Manga{}
    |> Manga.create_changeset(parse_manga(attrs[:url]))
    |> Repo.insert()
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
    mangas = list_mangas()

    Enum.each(mangas, fn m ->
      update_manga(m, parse_manga(m.url))
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

  def parse_manga(url) do
    tesla_client =
      Tesla.client([
        Tesla.Middleware.FollowRedirects
        # Tesla.Middleware.Logger
      ])

    {:ok, request} = Tesla.get(tesla_client, url)
    html = request.body
    {:ok, doc} = Floki.parse_document(html)

    name =
      Enum.find_value([".main-head h1", "h1.entry-title"], fn el ->
        Floki.find(doc, el) |> Floki.text() |> wrap_empty()
      end)

    links =
      Enum.find_value([".chapter-list a", "#chapterlist a"], [], fn el ->
        Floki.attribute(doc, el, "href") |> wrap_empty()
      end)

    last_chapter =
      Enum.map(links, fn l ->
        Regex.scan(~r/chapter-(\d*)/, l) |> hd() |> List.last() |> String.to_integer()
      end)
      |> Enum.max()

    Logger.info("successfully got info of manga #{url}")
    %{name: name, url: request.url, last_chapter: last_chapter}
  rescue
    e ->
      Logger.error("could not update manga #{url}: #{inspect(e)}")
      %{}
  end

  defp wrap_empty(val) when val == "", do: false
  defp wrap_empty(val) when val == [], do: false
  defp wrap_empty(val), do: val
end
