defmodule MangaWatcher.Repo.Migrations.RemoveTagPrefsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :include_tags, {:array, :string}, null: false, default: []
      remove :exclude_tags, {:array, :string}, null: false, default: []
    end
  end
end
