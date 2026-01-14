defmodule MangaWatcherWeb.Api.TagController do
  use MangaWatcherWeb, :controller

  alias MangaWatcher.Series

  def index(conn, _params) do
    tags = Series.list_tags()
    json(conn, tags)
  end
end
