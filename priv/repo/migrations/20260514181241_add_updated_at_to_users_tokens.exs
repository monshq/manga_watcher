defmodule MangaWatcher.Repo.Migrations.AddUpdatedAtToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :updated_at, :naive_datetime, null: true
    end

    execute "UPDATE users_tokens SET updated_at = inserted_at"

    alter table(:users_tokens) do
      modify :updated_at, :naive_datetime, null: false
    end
  end
end
