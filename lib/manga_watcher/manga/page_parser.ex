defmodule MangaWatcher.Manga.PageParser do
  @titles [".main-head h1", "h1.entry-title"]
  @links [".chapter-list a", "#chapterlist a"]
  @previews ["figure.cover img", ".thumbook img"]

  @spec parse(binary) :: {:ok, map} | {:error, atom}
  def parse(page) do
    {:ok, doc} = Floki.parse_document(page)

    websites = MangaSources.list_websites()

    name =
      Enum.find_value(@titles, fn el ->
        Floki.find(doc, el) |> Floki.text() |> wrap_empty()
      end)

    preview =
      Enum.find_value(@previews, fn el ->
        Floki.attribute(doc, el, "src") |> first_or_false()
      end)

    links =
      Enum.find_value(@links, [], fn el ->
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

    res = %{name: name, last_chapter: last_chapter, preview: preview}
    {:ok, res}
  rescue
    e ->
      {:error, e}
  end

  defp wrap_empty(val) when val == "", do: false
  defp wrap_empty(val) when val == [], do: false
  defp wrap_empty(val), do: val

  defp first_or_false([_] = l), do: hd(l)
  defp first_or_false(_), do: false
end
