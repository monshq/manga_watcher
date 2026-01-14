defmodule MangaWatcher.Series.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Series.Manga

  @derive {Jason.Encoder, only: [:id, :name]}
  schema "tags" do
    field :name, :string

    many_to_many :mangas, Manga, join_through: "manga_tags"

    timestamps()
  end

  @doc """
  Only required by Manga.add_tag function
  """
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:id, :name])
    |> validate_required([:name])
  end
end
