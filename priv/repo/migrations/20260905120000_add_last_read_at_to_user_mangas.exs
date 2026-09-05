defmodule MangaWatcher.Repo.Migrations.AddLastReadAtToUserMangas do
  use Ecto.Migration

  def up do
    alter table(:user_mangas) do
      add :last_read_at, :naive_datetime
    end

    # the last time the row changed is the best approximation of the last read
    execute "UPDATE user_mangas SET last_read_at = updated_at"

    alter table(:user_mangas) do
      modify :last_read_at, :naive_datetime, null: false
    end
  end

  def down do
    alter table(:user_mangas) do
      remove :last_read_at
    end
  end
end
