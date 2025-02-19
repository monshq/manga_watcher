defmodule MangaWatcher.Repo.Migrations.AddTagPrefsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :include_tags, {:array, :string}, null: false, default: []
      add :exclude_tags, {:array, :string}, null: false, default: []
    end
  end
end
