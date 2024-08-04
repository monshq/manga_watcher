defmodule MangaWatcher.Series.UserManga do
  use Ecto.Schema
  import Ecto.Changeset

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.Accounts.User

  @primary_key false
  schema "user_mangas" do
    belongs_to :user, User, primary_key: true
    belongs_to :manga, Manga, primary_key: true

    field :last_read_chapter, :integer

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :manga_id, :last_read_chapter])
    |> unique_constraint(:user_manga_already_exists, name: "user_mangas_pkey")
  end

  def changeset(user_manga, attrs) do
    user_manga
    |> cast(attrs, [:last_read_chapter])
  end
end
