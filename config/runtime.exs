import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/manga_watcher start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

if config_env() == :prod do
  config :manga_watcher, MangaWatcher.Repo,
    username: System.fetch_env!("DB_USERNAME"),
    password: System.fetch_env!("DB_PASSWORD"),
    hostname: System.fetch_env!("DB_HOSTNAME"),
    database: System.fetch_env!("DB_NAME"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :manga_watcher, MangaWatcherWeb.Endpoint,
    url: [
      host: System.fetch_env!("PHX_HOST"),
      port: 80
    ],
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PHX_PORT", "4000"))
    ],
    server: true,
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
