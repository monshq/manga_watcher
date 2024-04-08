defmodule MangaWatcher.Series.Website do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Repo
  alias MangaWatcher.Utils

  schema "websites" do
    field :base_url, :string
    field :title_regex, :string
    field :links_regex, :string
    field :preview_regex, :string

    timestamps()
  end

  @doc false
  def changeset(website, attrs) do
    website
    |> cast(attrs, [:base_url, :title_regex, :links_regex, :preview_regex])
    |> validate_required([:base_url, :title_regex, :links_regex, :preview_regex])
    |> normalize_url()
    |> unsafe_validate_unique(:base_url, Repo)
    |> unique_constraint(:base_url)
  end

  defp normalize_url(changeset) do
    url = changeset |> get_field(:base_url)

    if url do
      cast(changeset, %{base_url: Utils.normalize_host(url)}, [:base_url])
    else
      changeset
    end
  end
end
