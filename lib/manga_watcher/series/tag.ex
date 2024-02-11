defmodule MangaWatcher.Series.Tag do
  use Ecto.Schema

  alias MangaWatcher.Series.Manga

  schema "tags" do
    field :name, :string

    many_to_many :mangas, Manga, join_through: "manga_tags"

    timestamps()
  end
end
