defmodule MangaWatcher.Utils do
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {to_atom(k), atomize_keys(v)}
    end)
  end

  def atomize_keys(map), do: map

  defp to_atom(s) when is_binary(s), do: String.to_existing_atom(s)
  defp to_atom(a), do: a
end
