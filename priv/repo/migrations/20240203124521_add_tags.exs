defmodule MangaWatcher.Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string
      timestamps()
    end

    create unique_index(:tags, [:name])

    create table(:manga_tags, primary_key: false) do
      add :tag_id, references(:tags, on_delete: :delete_all)
      add :manga_id, references(:mangas, on_delete: :delete_all)
    end
  end
end
