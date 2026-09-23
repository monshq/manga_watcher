defmodule MangaWatcher.Manga.PageParser do
  alias MangaWatcher.Series.Website

  @behaviour __MODULE__
  @callback parse(html :: binary(), website :: struct()) :: {:ok, map()} | {:error, term()}

  # lazy-loaded images keep the real url in data-* attributes, meta tags (og:image) in content
  @preview_attributes ["src", "data-src", "data-lazy-src", "content"]
  @samples 5

  @spec parse(binary, Website.t()) :: {:ok, map} | {:error, any}
  def parse(page, %Website{} = website) do
    {:ok, doc} = Floki.parse_document(page)

    [title_node] = Floki.find(doc, website.title_regex)

    preview =
      case Floki.find(doc, website.preview_regex) do
        [node] -> preview_url(node, website.base_url)
        _ -> nil
      end

    last_chapter =
      doc
      |> Floki.find(website.links_regex)
      |> Stream.map(&extract_chapter/1)
      |> Stream.reject(&is_nil/1)
      |> Enum.max()

    res = %{name: extract_name(title_node), last_chapter: last_chapter, preview: preview}
    {:ok, res}
  rescue
    Enum.EmptyError ->
      {:error, "could not find any chapter links"}

    e ->
      {:error, e}
  end

  @doc """
  Reports what every selector of the website matches on the page instead of
  failing on the first problem. Used to check selectors before saving them.
  """
  @spec diagnose(binary, Website.t()) :: map
  def diagnose(page, %Website{} = website) do
    {:ok, doc} = Floki.parse_document(page)

    %{
      title: safely(fn -> diagnose_title(doc, website.title_regex) end),
      links: safely(fn -> diagnose_links(doc, website.links_regex) end),
      preview: safely(fn -> diagnose_preview(doc, website.preview_regex, website.base_url) end)
    }
  end

  defp diagnose_title(doc, selector) do
    names = doc |> Floki.find(selector) |> Enum.map(&extract_name/1)

    %{
      matches: length(names),
      value: if(length(names) == 1, do: hd(names)),
      samples: Enum.take(names, @samples)
    }
  end

  defp diagnose_links(doc, selector) do
    links =
      doc
      |> Floki.find(selector)
      |> Enum.map(fn node ->
        %{
          chapter: extract_chapter(node),
          href: node |> Floki.attribute("href") |> List.first(),
          text: node |> Floki.text() |> String.trim()
        }
      end)

    chapter_links =
      links |> Enum.reject(&is_nil(&1.chapter)) |> Enum.sort_by(& &1.chapter, :desc)

    %{
      matches: length(links),
      with_chapter: length(chapter_links),
      max_chapter: chapter_links |> Enum.map(& &1.chapter) |> Enum.max(fn -> nil end),
      samples: Enum.take(if(chapter_links == [], do: links, else: chapter_links), @samples)
    }
  end

  defp diagnose_preview(doc, selector, base_url) do
    nodes = Floki.find(doc, selector)

    %{
      matches: length(nodes),
      url: if(length(nodes) == 1, do: preview_url(hd(nodes), base_url))
    }
  end

  defp safely(fun) do
    fun.()
  rescue
    e -> %{error: Exception.message(e)}
  end

  # ignore nested tags, it's likely they are not part of a name but labels like "HOT"
  defp extract_name({_tag, _attrs, children}) do
    children
    |> Enum.filter(&is_binary/1)
    |> Enum.map_join(" ", &String.trim/1)
    |> String.trim()
  end

  defp preview_url(node, base_url) do
    @preview_attributes
    |> Enum.flat_map(&Floki.attribute(node, &1))
    |> Enum.map(&String.trim/1)
    |> Enum.find(&(&1 != "" and not String.starts_with?(&1, "data:")))
    |> normalize_url(base_url)
  end

  defp extract_chapter(node) do
    doc = Floki.raw_html(node)

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
    cond do
      String.starts_with?(url, "//") -> "https:#{url}"
      String.starts_with?(url, "/") -> "http://#{base_url}#{url}"
      true -> url
    end
  end
end
