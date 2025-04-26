defmodule MangaWatcher.Manga.AttrFetcher do
  alias MangaWatcher.Series
  alias MangaWatcher.PreviewUploader

  require Logger

  @behaviour __MODULE__
  @callback fetch(map(), map()) :: {:ok, map()} | {:error, any()}
  @callback fetch(map()) :: {:ok, map()} | {:error, any()}

  @spec fetch(manga_attrs :: map(), deps :: map()) :: {:ok, map()} | {:error, any()}
  def fetch(manga_attrs, deps \\ default_deps()) do
    with {:ok, url} <- Map.fetch(manga_attrs, :url),
         {:ok, website} <- Series.get_website_for_url(url),
         {:ok, html_content} <- deps.downloader.download(url),
         {:ok, attrs} <- deps.page_parser.parse(html_content, website),
         Logger.info("found following attrs for manga: #{inspect(attrs)}"),
         {:ok, preview} <-
           store_preview(
             %{
               preview_url: attrs[:preview],
               existing_preview: manga_attrs[:preview],
               manga_name: attrs[:name],
               manga_url: url
             },
             deps
           ) do
      {:ok, manga_attrs |> Map.merge(attrs) |> Map.merge(%{preview: preview})}
    else
      :error ->
        {:error, "url is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_preview(
         %{existing_preview: original_preview} = input,
         deps
       )
       when original_preview != nil do
    if PreviewUploader.exists?(original_preview) do
      {:ok, original_preview}
    else
      store_preview(Map.put(input, :existing_preview, nil), deps)
    end
  end

  defp store_preview(%{preview_url: nil}, _deps), do: {:ok, nil}

  defp store_preview(
         %{
           preview_url: new_preview,
           manga_name: name,
           manga_url: url
         },
         %{downloader: downloader}
       ) do
    Logger.debug("downloading preview from #{new_preview}")

    case downloader.download(new_preview, get_referer(url)) do
      {:ok, preview_bin} ->
        PreviewUploader.store(%{
          filename: preview_filename(name, new_preview),
          binary: preview_bin
        })

      {:error, error} ->
        Logger.error("could not download preview for #{name}: #{inspect(error)}")
        {:ok, nil}
    end
  end

  defp preview_filename(manga_name, url) do
    name =
      manga_name
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
      |> String.replace(~r/[^A-z]+/, "")

    ext =
      url |> Path.extname() |> String.downcase()

    name <> ext
  end

  defp get_referer(url) do
    "https://" <> URI.parse(url).host
  rescue
    _ -> ""
  end

  defp default_deps do
    %{
      downloader: Application.get_env(:manga_watcher, :page_downloader),
      page_parser: MangaWatcher.Manga.PageParser
    }
  end
end
