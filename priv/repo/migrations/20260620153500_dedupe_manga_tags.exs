defmodule MangaWatcher.Repo.Migrations.DedupeMangaTags do
  use Ecto.Migration

  def change do
    create unique_index(:manga_tags, [:manga_id, :tag_id])
  end
end
