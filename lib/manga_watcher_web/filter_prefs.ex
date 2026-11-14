defmodule MangaWatcherWeb.FilterPrefs do
  @moduledoc """
  The standing ("base") manga filter of a browser lives in a browser-written cookie.

  The browser writes the cookie on `phx:filter_base` events and sends it as a
  connect param; this plug copies it into the session so the disconnected
  render can apply the same filter.

  Browsers still carrying the old `tag_prefs` cookie (lists of included and
  excluded tags) get it converted into an equivalent base filter.
  """

  import Plug.Conn

  alias MangaWatcher.MangaFilter

  @cookie "filter_base"
  @legacy_cookie "tag_prefs"
  @max_age 365 * 24 * 60 * 60
  @max_length 1000
  @max_tags 100

  def max_length, do: @max_length

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    {conn, value} =
      case conn.cookies do
        %{@cookie => value} ->
          {conn, value}

        %{@legacy_cookie => legacy} ->
          value = legacy |> convert_legacy() |> encode()

          conn =
            conn
            |> put_resp_cookie(@cookie, value,
              http_only: false,
              max_age: @max_age,
              same_site: "Lax"
            )
            |> delete_resp_cookie(@legacy_cookie)

          {conn, value}

        _ ->
          {conn, nil}
      end

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
  Decodes a raw (URI-encoded) cookie value into the filter query string.
  Anything malformed falls back to no filtering.
  """
  @spec decode(term()) :: String.t()
  def decode(value) when is_binary(value) do
    query = URI.decode(value)
    if String.valid?(query) and String.length(query) <= @max_length, do: query, else: ""
  rescue
    ArgumentError -> ""
  end

  def decode(_), do: ""

  # same escaping as encodeURIComponent, which the browser uses when it writes the cookie
  defp encode(query), do: URI.encode(query, &URI.char_unreserved?/1)

  defp convert_legacy(value) do
    with json when json != "" <- decode(value),
         {:ok, %{"include" => include, "exclude" => exclude}} <- Jason.decode(json),
         true <- tag_list?(include) and tag_list?(exclude) do
      included =
        case Enum.map(include, &{:tag, &1}) do
          [] -> []
          [tag] -> [tag]
          tags -> [{:or, tags}]
        end

      MangaFilter.to_string({:and, included ++ Enum.map(exclude, &{:not, {:tag, &1}})})
    else
      _ -> ""
    end
  end

  defp tag_list?(tags) do
    is_list(tags) and length(tags) <= @max_tags and Enum.all?(tags, &is_binary/1)
  end
end
