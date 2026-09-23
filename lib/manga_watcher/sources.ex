defmodule MangaWatcher.Sources do
  @moduledoc """
  Checking and saving manga websites (sources) for the agent api. Pages are
  always fetched and parsed by the app itself, so the results match what the
  update poller will see.
  """

  alias MangaWatcher.Manga.AttrFetcher
  alias MangaWatcher.Manga.PageParser
  alias MangaWatcher.Series
  alias MangaWatcher.Series.Website
  alias MangaWatcher.Sources.BlockDetector
  alias MangaWatcher.Utils

  require Logger

  @type selectors :: %{title: String.t(), links: String.t(), preview: String.t()}

  @min_verified_urls 2
  @existing_mangas_to_check 5
  @same_host_interval Application.compile_env(:manga_watcher, :same_host_interval)

  def list do
    counts = Series.website_counts()

    Enum.map(Series.list_websites(), fn website ->
      %{
        host: website.base_url,
        selectors: selectors(website),
        mangas: counts[website.id].total,
        broken: counts[website.id].broken,
        sample_urls: Series.list_manga_urls_for_host(website.base_url, 3)
      }
    end)
  end

  @doc """
  Downloads the page and tells whether it can be parsed without a browser.
  """
  def probe(url, deps \\ default_deps()) do
    with {:ok, resp} <- deps.downloader.fetch(url, guard: true) do
      {verdict, reason} = BlockDetector.classify(resp)
      host = Utils.normalize_host(url)

      {:ok,
       %{
         url: url,
         final_url: resp.url,
         host: host,
         status: resp.status,
         verdict: verdict,
         reason: reason,
         existing_source: host |> Series.get_website_by_host() |> source(),
         html: if(is_binary(resp.body), do: resp.body, else: "")
       }}
    end
  end

  @doc """
  Parses every url with the given selectors and reports what each selector
  matched. The preview is downloaded the same way the app downloads it.
  """
  @spec test([String.t()], selectors(), map()) :: [map()]
  def test(urls, selectors, deps \\ default_deps()) do
    urls
    |> Enum.with_index()
    |> Enum.map(fn {url, i} ->
      if i > 0, do: Process.sleep(@same_host_interval)
      test_url(url, selectors, deps)
    end)
  end

  @doc """
  Creates or updates the website for `host` after checking the selectors on
  `verified_urls` and, when the website exists, on its latest mangas. Updating
  an existing website requires the `confirm: true` option.
  """
  def save(host, selectors, verified_urls, opts \\ [], deps \\ default_deps()) do
    host = Utils.normalize_host(host)
    existing = Series.get_website_by_host(host)

    with {:ok, verified_urls} <- validate_urls(host, verified_urls) do
      existing_urls =
        if existing,
          do: Series.list_manga_urls_for_host(host, @existing_mangas_to_check) -- verified_urls,
          else: []

      reports =
        Enum.map(test(verified_urls, selectors, deps), &Map.put(&1, :kind, :verified)) ++
          Enum.map(test(existing_urls, selectors, deps), &Map.put(&1, :kind, :existing))

      cond do
        not Enum.all?(reports, &passed?/1) ->
          {:error, :tests_failed, reports}

        existing && !opts[:confirm] ->
          {:error, :needs_confirmation,
           %{current: selectors(existing), proposed: selectors, reports: reports}}

        true ->
          persist(existing, host, selectors, reports)
      end
    end
  end

  defp persist(nil, host, selectors, reports) do
    attrs = selectors |> website_attrs() |> Map.put(:base_url, host)

    with {:ok, website} <- Series.create_website(attrs) do
      Logger.info("created website #{host}: #{inspect(selectors)}")
      {:ok, :created, source(website), reports}
    end
  end

  defp persist(%Website{} = existing, host, selectors, reports) do
    with {:ok, website} <- Series.update_website(existing, website_attrs(selectors)) do
      Logger.info("updated selectors of website #{host}: #{inspect(selectors)}")
      Series.unbreak_mangas_for_host(host)
      {:ok, :updated, source(website), reports}
    end
  end

  # existing mangas might have moved or been removed from the website, that
  # says nothing about the selectors
  defp passed?(%{kind: :existing, verdict: :http_error}), do: true
  defp passed?(report), do: report.ok

  defp validate_urls(host, urls) when is_list(urls) do
    urls = urls |> Enum.filter(&is_binary/1) |> Enum.map(&Utils.normalize_url/1) |> Enum.uniq()

    cond do
      Enum.any?(urls, &(Utils.normalize_host(&1) != host)) ->
        {:error, :invalid_urls, "all verified urls must belong to #{host}"}

      length(urls) < @min_verified_urls ->
        {:error, :invalid_urls,
         "at least #{@min_verified_urls} different manga urls are required for verification"}

      true ->
        {:ok, urls}
    end
  end

  defp validate_urls(_host, _urls), do: {:error, :invalid_urls, "verified urls must be a list"}

  defp test_url(url, selectors, deps) do
    case deps.downloader.fetch(url, guard: true) do
      {:ok, resp} ->
        {verdict, reason} = BlockDetector.classify(resp)
        report = %{url: url, final_url: resp.url, status: resp.status, verdict: verdict}

        if verdict == :ok do
          website = selectors |> website_attrs() |> Map.put(:base_url, Utils.normalize_host(url))
          diagnostics = PageParser.diagnose(resp.body, struct(Website, website))

          preview =
            Map.put(diagnostics.preview, :download, check_preview(diagnostics.preview, url, deps))

          report = report |> Map.merge(diagnostics) |> Map.put(:preview, preview)
          errors = errors(report)
          Map.merge(report, %{ok: errors == [], errors: errors})
        else
          Map.merge(report, %{ok: false, errors: [reason]})
        end

      {:error, e} ->
        %{url: url, verdict: :fetch_error, ok: false, errors: [error_message(e)]}
    end
  end

  defp check_preview(%{url: preview_url}, page_url, deps) when is_binary(preview_url) do
    case deps.downloader.fetch(preview_url, referer: AttrFetcher.referer(page_url), guard: true) do
      {:ok, %{status: status, headers: headers, body: body}} ->
        content_type = headers |> Map.get("content-type", []) |> List.first()

        %{
          # hotlink protection often answers with an html page instead of the image
          ok: status == 200 and not String.starts_with?(content_type || "", "text/"),
          status: status,
          content_type: content_type,
          bytes: if(is_binary(body), do: byte_size(body))
        }

      {:error, e} ->
        %{ok: false, error: error_message(e)}
    end
  end

  defp check_preview(_preview, _page_url, _deps), do: nil

  defp errors(report) do
    [
      field_error(:title, report.title) || title_error(report.title),
      field_error(:links, report.links) || links_error(report.links),
      field_error(:preview, report.preview) || preview_error(report.preview)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp title_error(%{matches: matches}) when matches != 1,
    do: "title selector matched #{matches} elements, expected exactly 1"

  defp title_error(%{value: ""}), do: "title element has no text of its own"
  defp title_error(_title), do: nil

  defp links_error(%{with_chapter: 0, matches: matches}),
    do: "links selector matched #{matches} elements, none has a chapter number"

  defp links_error(_links), do: nil

  defp preview_error(%{matches: matches}) when matches != 1,
    do: "preview selector matched #{matches} elements, expected exactly 1"

  defp preview_error(%{url: nil}), do: "preview element has no image url"

  defp preview_error(%{download: %{ok: false} = download}),
    do: "preview download failed: #{inspect(Map.delete(download, :ok))}"

  defp preview_error(_preview), do: nil

  defp field_error(field, %{error: error}), do: "#{field} selector failed: #{error}"
  defp field_error(_field, _diagnostics), do: nil

  defp error_message(e) when is_exception(e), do: Exception.message(e)
  defp error_message(e) when is_binary(e), do: e
  defp error_message(e), do: inspect(e)

  defp website_attrs(selectors) do
    %{
      title_regex: selectors[:title],
      links_regex: selectors[:links],
      preview_regex: selectors[:preview]
    }
  end

  defp selectors(%Website{} = website) do
    %{title: website.title_regex, links: website.links_regex, preview: website.preview_regex}
  end

  defp source(nil), do: nil
  defp source(%Website{} = website), do: %{host: website.base_url, selectors: selectors(website)}

  defp default_deps do
    %{downloader: Application.get_env(:manga_watcher, :page_downloader)}
  end
end
