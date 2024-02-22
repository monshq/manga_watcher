defmodule MangaWatcher.Series.Manga do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Repo
  alias MangaWatcher.Series.Tag
  alias MangaWatcher.Utils

  import Ecto.Query

  schema "mangas" do
    field :last_chapter, :integer
    field :last_read_chapter, :integer
    field :name, :string
    field :url, :string
    field :failed_updates, :integer, default: 0

    many_to_many :tags, Tag, join_through: "manga_tags", on_replace: :delete

    timestamps()
  end

  # From https://tools.ietf.org/html/rfc3986#appendix-B
  # and https://github.com/elixir-lang/elixir/blob/v1.12.3/lib/elixir/lib/uri.ex#L534
  # @url_format ~r{^(([a-z][a-z0-9\+\-\.]*):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}i
  @url_format ~r{^((http|https)://)?[\w\d\.\-\/]+\z}i

  def pre_create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:url])
    |> validate_required([:url])
    |> validate_format(:url, @url_format)
    |> normalize_url()
    |> unsafe_validate_unique(:url, Repo)
  end

  @doc false
  def create_changeset(attrs) do
    pre_create_changeset(attrs)
    |> cast(attrs, [:name, :url, :last_read_chapter, :last_chapter])
    |> unique_constraint(:url)
    |> put_tags_if_changed(attrs)
  end

  @doc false
  def pre_update_changeset(manga, attrs) do
    manga
    |> cast(attrs, [:name, :url, :last_read_chapter, :last_chapter, :failed_updates])
    |> validate_required([:name, :url, :last_read_chapter, :last_chapter])
    |> validate_format(:url, @url_format)
    |> normalize_url()
    |> unsafe_validate_unique(:url, Repo)
    |> unique_constraint(:url)
  end

  @doc false
  def update_changeset(manga, attrs) do
    manga
    |> pre_update_changeset(attrs)
    |> put_tags_if_changed(attrs)
  end

  defp normalize_url(changeset) do
    url = changeset |> get_field(:url)

    if url do
      cast(changeset, %{url: Utils.normalize_url(url)}, [:url])
    else
      changeset
    end
  end

  defp put_tags_if_changed(cs, attrs) do
    if attrs["tags"] do
      put_assoc(cs, :tags, parse_tags(attrs))
    else
      cs
    end
  end

  defp parse_tags(params) do
    (params["tags"] || "")
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
