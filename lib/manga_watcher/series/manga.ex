defmodule MangaWatcher.Series.Manga do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Repo

  schema "mangas" do
    field :last_chapter, :integer
    field :last_read_chapter, :integer
    field :name, :string
    field :url, :string

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
    %__MODULE__{}
    |> cast(attrs, [:name, :url, :last_read_chapter, :last_chapter])
    |> validate_required([:name, :url, :last_read_chapter, :last_chapter])
    |> validate_format(:url, @url_format)
    |> normalize_url()
    |> validate_format(:url, ~r/\d*/)
    |> unique_constraint(:url)
  end

  @doc false
  def update_changeset(manga, attrs) do
    manga
    |> cast(attrs, [:name, :url, :last_read_chapter, :last_chapter])
    |> validate_required([:name, :url, :last_read_chapter, :last_chapter])
    |> validate_format(:url, @url_format)
    |> normalize_url()
    |> unsafe_validate_unique(:url, Repo)
    |> unique_constraint(:url)
  end

  defp normalize_url(changeset) do
    url = changeset |> get_field(:url)

    if url do
      cast(changeset, %{url: normalized_url(url)}, [:url])
    else
      changeset
    end
  end

  defp normalized_url(url) do
    uri = URI.parse(url |> String.trim_trailing("/"))
    host_and_path = wrap(uri.host) <> wrap(uri.path)

    if is_binary(uri.scheme) do
      uri.scheme <> "://" <> host_and_path
    else
      host_and_path
    end
  end

  defp wrap(b) when is_binary(b), do: b
  defp wrap(_), do: ""
end
