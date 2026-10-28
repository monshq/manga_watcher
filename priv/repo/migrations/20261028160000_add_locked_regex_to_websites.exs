defmodule MangaWatcher.Repo.Migrations.AddLockedRegexToWebsites do
  use Ecto.Migration

  def change do
    alter table(:websites) do
      add :locked_regex, :string
    end
  end
end
