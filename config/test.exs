import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :manga_watcher, MangaWatcher.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "manga_watcher_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :manga_watcher, MangaWatcherWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/0HNZah38Sv7rlkOg+5XGJlQ7ahPRAos7gT+8oLdCQzMAN7HhZdtKJtKPJfedzvQ",
  server: false

# In test we don't send emails.
config :manga_watcher, MangaWatcher.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :manga_watcher, :page_downloader, MangaWatcher.Fake.Downloader
config :manga_watcher, :same_host_interval, 5

config :waffle,
  storage: Waffle.Storage.Local,
  storage_dir: "images",
  storage_dir_prefix: "tmp/static"
