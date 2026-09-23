defmodule MangaWatcherWeb.TagPrefs do
  @moduledoc """
  Tag filter preferences live in a browser-written cookie.

  The browser writes the cookie on `phx:tag_prefs` events and sends it as a
  connect param; this plug copies it into the session so the disconnected
  render can apply the same filter.
  """

  import Plug.Conn

  @cookie "tag_prefs"
  @max_tags 100

  def init(opts), do: opts

  def call(conn, _opts) do
    value = conn |> fetch_cookies() |> Map.get(:cookies) |> Map.get(@cookie)

    cond do
      value == get_session(conn, @cookie) -> conn
      is_nil(value) -> delete_session(conn, @cookie)
      true -> put_session(conn, @cookie, value)
    end
  end

  @doc """
  Returns the raw cookie value for the current mount: connect params when
  connected (fresh on every live navigation), the session otherwise.
  """
  def from_socket(socket, session) do
    if Phoenix.LiveView.connected?(socket),
      do: Phoenix.LiveView.get_connect_params(socket)[@cookie],
      else: session[@cookie]
  end

  @doc """
  Parses a raw (URI-encoded JSON) cookie value into `{include_tags, exclude_tags}`.
  Anything malformed falls back to no filtering.
  """
  def parse(value) when is_binary(value) do
    with {:ok, json} <- uri_decode(value),
         {:ok, %{"include" => include, "exclude" => exclude}} <- Jason.decode(json),
         true <- tag_list?(include) and tag_list?(exclude) do
      {include, exclude}
    else
      _ -> {[], []}
    end
  end

  def parse(_), do: {[], []}

  defp uri_decode(value) do
    {:ok, URI.decode(value)}
  rescue
    ArgumentError -> :error
  end

  defp tag_list?(tags) do
    is_list(tags) and length(tags) <= @max_tags and Enum.all?(tags, &is_binary/1)
  end
end
