defmodule MangaWatcher.Repo.Migrations.AddLastChapterUpdatedAtToMangas do
  use Ecto.Migration

  def change do
    alter table("mangas") do
      add :last_chapter_updated_at, :timestamp,
        null: false,
        default: DateTime.utc_now() |> DateTime.to_iso8601()
    end
  end
end
