defmodule MangaWatcher.Utils do
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

  def normalize_host(url) when is_binary(url) do
    if String.match?(url, ~r/http.*/) do
      URI.parse(url).host
    else
      URI.parse("http://#{url}").host
    end
  end

  defp wrap(b) when is_binary(b), do: b
  defp wrap(_), do: ""
end
