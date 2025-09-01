defmodule MangaWatcher.Series.Manga do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Repo
  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Series.UserManga
  alias MangaWatcher.Accounts.User
  alias MangaWatcher.Utils

  import Ecto.Query

  schema "mangas" do
    field :name, :string
    field :url, :string
    field :failed_updates, :integer, default: 0
    field :preview, :string

    field :last_chapter, :integer

    field :last_chapter_updated_at, :naive_datetime,
      default: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    many_to_many :tags, Tag, join_through: "manga_tags", on_replace: :delete

    has_many :user_mangas, UserManga
    many_to_many :users, User, join_through: UserManga, on_replace: :delete

    timestamps()
  end

  @url_format ~r{^((http|https)://)?[\w\d\.\-\/']+\z}i

  def pre_create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:url])
    |> validate_required([:url])
    |> validate_format(:url, @url_format)
    |> normalize_url()

    # |> unsafe_validate_unique(:url, Repo)
  end

  @doc false
  def create_changeset(attrs) do
    pre_create_changeset(attrs)
    |> cast(attrs, [:name, :url, :last_chapter, :preview])
    |> unique_constraint(:url)
    |> put_last_chapter_updated_at()
    |> put_tags_if_changed(attrs)
  end

  @doc false
  def pre_update_changeset(manga, attrs) do
    manga
    |> cast(attrs, [:name, :url, :last_chapter, :failed_updates, :preview])
    |> validate_required([:name, :url, :last_chapter])
    |> validate_format(:url, @url_format)
    |> normalize_url()
    |> unsafe_validate_unique(:url, Repo)
    |> unique_constraint(:url)
  end

  @doc false
  def update_changeset(manga, attrs) do
    manga
    |> pre_update_changeset(attrs)
    |> put_last_chapter_updated_at()
    |> put_tags_if_changed(attrs)
    |> put_user_mangas_if_present(attrs)
  end

  def add_tag(manga, tag) do
    manga = manga |> Repo.preload(:tags)
    tags = [tag | manga.tags]

    manga
    |> cast(%{}, [])
    |> put_assoc(:tags, tags)
  end

  def remove_tag(manga, tag_name) do
    manga = manga |> Repo.preload(:tags)
    # would be easier to just delete the record in manga_tags
    tags = Enum.filter(manga.tags, fn t -> tag_name != t.name end)

    manga
    |> cast(%{}, [])
    |> put_assoc(:tags, tags)
  end

  defp normalize_url(changeset) do
    url = changeset |> get_field(:url)

    if url do
      cast(changeset, %{url: Utils.normalize_url(url)}, [:url])
    else
      changeset
    end
  end

  defp put_user_mangas_if_present(cs, attrs) do
    if Map.has_key?(attrs, "user_mangas") do
      cs |> cast_assoc(:user_mangas)
    else
      cs
    end
  end

  defp put_last_chapter_updated_at(changeset) do
    if get_change(changeset, :last_chapter) do
      put_change(
        changeset,
        :last_chapter_updated_at,
        NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      )
    else
      changeset
    end
  end

  defp put_tags_if_changed(cs, attrs) do
    # TODO: parameters from outside should always come as binaries
    if (Map.has_key?(attrs, :tags) and is_binary(attrs[:tags])) ||
         (Map.has_key?(attrs, "tags") and is_binary(attrs["tags"])) do
      put_assoc(cs, :tags, parse_tags(attrs))
    else
      cs
    end
  end

  defp parse_tags(params) do
    (params[:tags] || params["tags"] || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> insert_and_get_all_tags()
  end

  defp insert_and_get_all_tags([]) do
    []
  end

  defp insert_and_get_all_tags(names) do
    timestamp =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    placeholders = %{timestamp: timestamp}

    maps =
      Enum.map(
        names,
        &%{
          name: &1,
          inserted_at: {:placeholder, :timestamp},
          updated_at: {:placeholder, :timestamp}
        }
      )

    Repo.insert_all(
      Tag,
      maps,
      placeholders: placeholders,
      on_conflict: :nothing
    )

    Repo.all(from t in Tag, where: t.name in ^names)
  end
end
