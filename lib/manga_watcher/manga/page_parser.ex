defmodule MangaWatcher.Manga.PageParser do
  alias MangaWatcher.Series.Website

  @behaviour __MODULE__
  @callback parse(html :: binary(), website :: struct()) :: {:ok, map()} | {:error, term()}

  @spec parse(binary, Website.t()) :: {:ok, map} | {:error, any}
  def parse(page, %Website{} = website) do
    {:ok, doc} = Floki.parse_document(page)

    name = Floki.find(doc, website.title_regex) |> Floki.text() |> String.trim()

    preview =
      Floki.attribute(doc, website.preview_regex, "src")
      |> first_or_nil()
      |> normalize_url(website.base_url)

    links = Floki.find(doc, website.links_regex)

    last_chapter =
      links
      |> Stream.map(&Floki.raw_html/1)
      |> Stream.map(&extract_chapter/1)
      |> Stream.reject(&is_nil/1)
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

  defp extract_chapter(doc) do
    # this regex tries to parse chapter number from href
    case extract_number(~r|chapter[-/](\d+)|, doc) do
      chapter when chapter < 1000 ->
        chapter

      # if chapter number is more than 1000 it's likely an id instead
      # so trying to get chapter number from text now
      _ ->
        extract_number(~r|chapter\s+(\d+)|iu, doc)
    end
  end

  defp extract_number(regex, text) do
    case Regex.scan(regex, text) do
      [[_, chapter]] -> String.to_integer(chapter)
      _ -> nil
    end
  end

  defp normalize_url(nil, _), do: nil

  defp normalize_url(url, base_url) do
    if String.starts_with?(url, "/") do
      "http://#{base_url}#{url}"
    else
      url
    end
  end
end
