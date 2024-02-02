defmodule MangaWatcher.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Ecto.Migrator,
         repos: Application.fetch_env!(:manga_watcher, :ecto_repos),
         skip: System.get_env("SKIP_MIGRATIONS") == "true"},
        # Start the Telemetry supervisor
        MangaWatcherWeb.Telemetry,
        # Start the Ecto repository
        MangaWatcher.Repo,
        # Start the PubSub system
        {Phoenix.PubSub, name: MangaWatcher.PubSub},
        # Start Finch
        {Finch, name: MangaWatcher.Finch},
        # Start the Endpoint (http/https)
        MangaWatcherWeb.Endpoint
        # Start a worker by calling: MangaWatcher.Worker.start_link(arg)
        # {MangaWatcher.Worker, arg}
      ]
      |> append_if(
        Application.get_env(:manga_watcher, MangaWatcher.Manga.UpdatePoller)[:enabled],
        MangaWatcher.Manga.UpdatePoller
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MangaWatcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MangaWatcherWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def append_if(list, true, value), do: [value | list]
  def append_if(list, false, _value), do: list
end
