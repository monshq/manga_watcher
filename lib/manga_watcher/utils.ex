defmodule MangaWatcher.Utils do
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {String.to_existing_atom(k), atomize_keys(v)}
    end)
  end

  def atomize_keys(map), do: map
end
