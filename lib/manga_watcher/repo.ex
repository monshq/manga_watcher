defmodule MangaWatcher.Repo do
  use Ecto.Repo,
    otp_app: :manga_watcher,
    adapter: Ecto.Adapters.Postgres
end
