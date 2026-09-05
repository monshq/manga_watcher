defmodule MangaWatcher.Repo.Migrations.AddDormantTag do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO tags (name, inserted_at, updated_at)
    VALUES ('dormant', NOW(), NOW())
    ON CONFLICT (name) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM tags WHERE name = 'dormant'"
  end
end
