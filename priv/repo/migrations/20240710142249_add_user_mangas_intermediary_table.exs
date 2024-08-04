defmodule MangaWatcher.Repo.Migrations.AddUserMangasIntermediaryTable do
  use Ecto.Migration

  def change do
    create table(:user_mangas, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :manga_id, references(:mangas, on_delete: :delete_all), primary_key: true
      add :last_read_chapter, :integer, null: false, default: 0
      timestamps()
    end

    alter table(:mangas) do
      remove(:last_read_chapter, :integer)
    end
  end
end
