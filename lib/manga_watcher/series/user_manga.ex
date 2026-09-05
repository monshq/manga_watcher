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
    field :last_read_at, :naive_datetime

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :manga_id, :last_read_chapter, :last_read_at])
    |> put_last_read_at_if_missing()
    |> unique_constraint(:user_manga_already_exists, name: "user_mangas_pkey")
    |> foreign_key_constraint(:user_does_not_exist, name: "user_mangas_user_id_fkey")
  end

  def changeset(user_manga, attrs) do
    user_manga
    |> cast(attrs, [:last_read_chapter])
    |> put_last_read_at_if_chapter_changed()
  end

  defp put_last_read_at_if_missing(changeset) do
    if get_field(changeset, :last_read_at) do
      changeset
    else
      put_change(changeset, :last_read_at, now())
    end
  end

  defp put_last_read_at_if_chapter_changed(changeset) do
    if get_change(changeset, :last_read_chapter) do
      put_change(changeset, :last_read_at, now())
    else
      changeset
    end
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
