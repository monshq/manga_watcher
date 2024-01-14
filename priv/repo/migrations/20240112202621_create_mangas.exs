defmodule MangaWatcher.Repo.Migrations.CreateMangas do
  use Ecto.Migration

  def change do
    create table(:mangas) do
      add :name, :string
      add :url, :string, unique: true
      add :last_read_chapter, :integer
      add :last_chapter, :integer

      timestamps()
    end

    create index(:mangas, :url, unique: true)
  end
end
