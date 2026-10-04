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
      {:ok, attrs |> Map.put(:url, url) |> Map.put(:preview, preview) |> put_tags(manga_attrs)}
    else
      :error ->
        {:error, "url is missing"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # the existing preview is kept whenever a new one cannot be stored, so an
  # unreachable storage or a failed download never wipes it from the manga
  defp store_preview(%{existing_preview: nil} = input, deps), do: download_preview(input, deps)

  defp store_preview(%{existing_preview: existing, manga_name: name} = input, deps) do
    case PreviewUploader.stored(existing) do
      {:ok, true} ->
        {:ok, existing}

      {:ok, false} ->
        download_preview(input, deps)

      {:error, error} ->
        Logger.error("could not check preview for #{name}: #{inspect(error)}")
        {:ok, existing}
    end
  end

  defp download_preview(%{preview_url: nil, existing_preview: existing}, _deps),
    do: {:ok, existing}

  defp download_preview(
         %{
           preview_url: new_preview,
           existing_preview: existing,
           manga_name: name,
           manga_url: url
         },
         %{downloader: downloader}
       ) do
    Logger.debug("downloading preview from #{new_preview}")

    case downloader.download(new_preview, referer(url)) do
      {:ok, preview_bin} ->
        store_preview_binary(preview_filename(name, new_preview), preview_bin, name, existing)

      {:error, error} ->
        Logger.error("could not download preview for #{name}: #{inspect(error)}")
        {:ok, existing}
    end
  end

  # thumbnail conversion fails when the download is not an image (e.g. a block page)
  defp store_preview_binary(filename, binary, name, existing) do
    case PreviewUploader.store(%{filename: filename, binary: binary}) do
      {:ok, filename} ->
        {:ok, filename}

      {:error, error} ->
        Logger.error("could not store preview for #{name}: #{inspect(error)}")
        {:ok, existing}
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

  @doc "Referer sent with preview downloads, some websites block hotlinking without it."
  def referer(url) do
    "https://" <> URI.parse(url).host
  rescue
    _ -> ""
  end

  defp put_tags(attrs, %{tags: tags}) when is_binary(tags), do: Map.put(attrs, :tags, tags)
  defp put_tags(attrs, _manga_attrs), do: attrs

  defp default_deps do
    %{
      downloader: Application.get_env(:manga_watcher, :page_downloader),
      page_parser: MangaWatcher.Manga.PageParser
    }
  end
end
