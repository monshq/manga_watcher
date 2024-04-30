defmodule MangaWatcherWeb.Router do
  use MangaWatcherWeb, :router

  import MangaWatcherWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MangaWatcherWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user

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

    live_session :current_user,
      on_mount: [{MangaWatcherWeb.UserAuth, :mount_current_user}] do
      live "/", MangaLive.Index, :index
      live "/mangas", MangaLive.Index, :index
      live "/mangas/new", MangaLive.Index, :new
      live "/mangas/:id/edit", MangaLive.Index, :edit

      live "/websites", WebsiteLive.Index, :index
      live "/websites/new", WebsiteLive.Index, :new
      live "/websites/:id/edit", WebsiteLive.Index, :edit

      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new

      delete "/users/log_out", UserSessionController, :delete
    end

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

  ## Authentication routes

  scope "/", MangaWatcherWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MangaWatcherWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MangaWatcherWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{MangaWatcherWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end
end
