defmodule MangaWatcher.Repo.Migrations.AddPreviewToMangas do
  use Ecto.Migration

  def change do
    alter table("mangas") do
      add :preview, :string
    end
  end
end
