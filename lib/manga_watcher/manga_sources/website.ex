defmodule MangaWatcher.MangaSources.Website do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Utils

  schema "websites" do
    field :base_url, :string
    field :title_regex, :string
    field :links_regex, :string

    timestamps()
  end

  @doc false
  def changeset(website, attrs) do
    website
    |> cast(attrs, [:base_url, :title_regex, :links_regex])
    |> validate_required([:base_url, :title_regex, :links_regex])
    |> normalize_url()
    |> unsafe_validate_unique(:url, Repo)
    |> unique_constraint(:url)
  end

  defp normalize_url(changeset) do
    url = changeset |> get_field(:url)

    if url do
      cast(changeset, %{url: Utils.normalize_url(url)}, [:url])
    else
      changeset
    end
  end
end
