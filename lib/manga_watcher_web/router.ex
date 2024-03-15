defmodule MangaWatcherWeb.Router do
  use MangaWatcherWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MangaWatcherWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug Plug.Static, at: "/images", from: {:app_name, "priv/static/images"}, gzip: false

    if Application.compile_env(:manga_watcher, :basic_auth)[:enabled] do
      plug :auth, Application.compile_env(:manga_watcher, :basic_auth)
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MangaWatcherWeb do
    pipe_through :browser

    # get "/", SeriesController, :home
    get "/series/new", SeriesController, :new
    post "/series", SeriesController, :create
    patch "/series/update", SeriesController, :update_all
    patch "/series/:id/read", SeriesController, :read

    live "/", MangaLive.Index, :index
    live "/mangas", MangaLive.Index, :index
    live "/mangas/:id/edit", MangaLive.Index, :edit
    live "/mangas/new", MangaLive.Index, :new
    live "/mangas/:id", MangaLive.Show, :show

    import Phoenix.LiveDashboard.Router
    live_dashboard "/dashboard", metrics: MangaWatcherWeb.Telemetry
  end

  # Other scopes may use custom stacks.
  # scope "/api", MangaWatcherWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:manga_watcher, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  def auth(conn, opts) do
    Plug.BasicAuth.basic_auth(conn, opts)
  end
end
