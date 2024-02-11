defmodule MangaWatcher.Manga.PageParser do
  @spec parse(binary) :: {:ok, map} | {:error, atom}
  def parse(page) do
    {:ok, doc} = Floki.parse_document(page)

    name =
      Enum.find_value([".main-head h1", "h1.entry-title"], fn el ->
        Floki.find(doc, el) |> Floki.text() |> wrap_empty()
      end)

    links =
      Enum.find_value([".chapter-list a", "#chapterlist a"], [], fn el ->
        Floki.attribute(doc, el, "href") |> wrap_empty()
      end)

    last_chapter =
      links
      |> Stream.map(fn l -> Regex.scan(~r/chapter-(\d*)/, l) end)
      |> Stream.reject(&Enum.empty?/1)
      |> Stream.map(&hd/1)
      |> Stream.map(&List.last/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&String.to_integer/1)
      |> Enum.max()

    res = %{name: name, last_chapter: last_chapter}
    {:ok, res}
  rescue
    e ->
      {:error, e}
  end

  defp wrap_empty(val) when val == "", do: false
  defp wrap_empty(val) when val == [], do: false
  defp wrap_empty(val), do: val
end
