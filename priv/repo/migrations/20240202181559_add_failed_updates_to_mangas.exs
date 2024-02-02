defmodule MangaWatcher.Repo.Migrations.AddFailedUpdatesToMangas do
  use Ecto.Migration

  def change do
    alter table("mangas") do
      add :failed_updates, :integer, default: 0, null: false
    end
  end
end
