defmodule MangaWatcher.Series.Manga do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mangas" do
    field :last_chapter, :integer
    field :last_read_chapter, :integer
    field :name, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def create_changeset(manga, attrs) do
    manga
    |> cast(attrs, [:name, :url, :last_read_chapter, :last_chapter])
    |> validate_required([:name, :url, :last_read_chapter, :last_chapter])
    |> unique_constraint(:url)
  end

  @doc false
  def update_changeset(manga, attrs) do
    manga
    |> cast(attrs, [:url, :last_read_chapter, :last_chapter])
    |> validate_required([:name, :url, :last_read_chapter, :last_chapter])
  end
end
