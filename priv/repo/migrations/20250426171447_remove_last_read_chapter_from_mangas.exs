defmodule MangaWatcher.Repo.Migrations.RemoveLastReadChapterFromMangas do
  use Ecto.Migration

  def change do
    alter table(:mangas) do
      remove :last_read_chapter, :integer, null: false, default: 0
    end
  end
end
