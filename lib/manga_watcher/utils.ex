defmodule MangaWatcher.Utils do
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {to_atom(k), atomize_keys(v)}
    end)
  end

  def atomize_keys(map), do: map

  defp to_atom(s) when is_binary(s), do: String.to_existing_atom(s)
  defp to_atom(a), do: a

  def normalize_url(url) do
    uri = URI.parse(url |> String.trim_trailing("/"))
    host_and_path = wrap(uri.host) <> wrap(uri.path)

    if is_binary(uri.scheme) do
      uri.scheme <> "://" <> host_and_path
    else
      host_and_path
    end
  end

  def normalize_host(nil), do: nil
  def normalize_host(url) when is_binary(url), do: URI.parse(url).host

  defp wrap(b) when is_binary(b), do: b
  defp wrap(_), do: ""
end
