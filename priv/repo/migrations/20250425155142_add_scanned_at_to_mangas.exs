defmodule MangaWatcher.Repo.Migrations.AddScannedAtToMangas do
  use Ecto.Migration

  def change do
    alter table("mangas") do
      add :scanned_at, :timestamp,
        null: false,
        default: DateTime.from_unix!(0) |> DateTime.to_iso8601()
    end
  end
end
