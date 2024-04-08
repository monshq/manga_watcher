defmodule MangaWatcher.Manga.PageParser do
  alias MangaWatcher.Series.Website

  @spec parse(binary, Website.t()) :: {:ok, map} | {:error, atom}
  def parse(page, %Website{} = website) do
    {:ok, doc} = Floki.parse_document(page)

    name = Floki.find(doc, website.title_regex) |> Floki.text()

    preview = Floki.attribute(doc, website.preview_regex, "src") |> first_or_nil()

    links = Floki.attribute(doc, website.links_regex, "href")

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
    Enum.EmptyError ->
      {:error, "could not find any chapter links"}

    e ->
      {:error, e}
  end

  defp first_or_nil([_] = l), do: hd(l)
  defp first_or_nil(_), do: nil
end
