defmodule MangaWatcher.Repo.Migrations.CreateWebsites do
  use Ecto.Migration

  def change do
    create table(:websites) do
      add :base_url, :string, null: false
      add :title_regex, :string
      add :links_regex, :string
      add :preview_regex, :string

      timestamps()
    end

    create unique_index(:websites, [:base_url])
  end
end
