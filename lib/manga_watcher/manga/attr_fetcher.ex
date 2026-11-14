defmodule MangaWatcher.Manga.AttrFetcher do
  alias MangaWatcher.Manga.AsuraApi
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
         {:ok, attrs} <- page_attrs(url, website, deps),
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

  defp page_attrs(url, website, deps) do
    if AsuraApi.handles?(url) do
      AsuraApi.fetch(url, deps.downloader)
    else
      with {:ok, html_content} <- deps.downloader.download(url) do
        deps.page_parser.parse(html_content, website)
      end
    end
  end

  # the existing preview is kept whenever a new one cannot be stored, so an
  # unreachable storage or a failed download never wipes it from the manga
  defp store_preview(%{existing_preview: nil} = input, deps), do: download_preview(input, deps)

  defp store_preview(%{existing_preview: existing, manga_name: name} = input, deps) do
    case PreviewUploader.stored(existing) do
      {:ok, true} ->
        ensure_thumb(input, deps)

      {:ok, false} ->
        download_preview(input, deps)

      {:error, error} ->
        Logger.error("could not check preview for #{name}: #{inspect(error)}")
        {:ok, existing}
    end
  end

  # the thumb is what is shown, an original is stored without it when the
  # thumb conversion fails. If the original cannot be converted, it is likely
  # not an image, so the preview is downloaded again
  defp ensure_thumb(%{existing_preview: existing, manga_name: name} = input, deps) do
    with {:ok, false} <- PreviewUploader.stored(existing, :thumb),
         {:error, error} <- PreviewUploader.generate_thumb(existing) do
      Logger.error("could not generate thumbnail for #{name}: #{inspect(error)}")
      download_preview(input, deps)
    else
      _ -> {:ok, existing}
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
        filename = preview_filename(name, url, new_preview)
        store_preview_binary(filename, preview_bin, name, existing)

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

  @doc """
  Storage name of a manga preview. The readable part comes from the manga name,
  the hash of the manga url keeps it unique, e.g. for names without latin letters.
  """
  def preview_filename(manga_name, manga_url, preview_url) do
    slug =
      (manga_name || "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")
      |> String.slice(0, 60)

    hash =
      :crypto.hash(:sha256, manga_url) |> Base.encode16(case: :lower) |> binary_part(0, 12)

    # the extension comes from the path only, query strings are not part of it
    ext = (URI.parse(preview_url).path || "") |> Path.extname() |> String.downcase()

    Enum.join(Enum.reject([slug, hash], &(&1 == "")), "_") <> ext
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
