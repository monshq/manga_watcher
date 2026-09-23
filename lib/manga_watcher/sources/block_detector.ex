defmodule MangaWatcher.Sources.BlockDetector do
  @moduledoc """
  Classifies a downloaded page by whether it can be parsed without a browser.
  """

  @type verdict :: :ok | :http_error | :cloudflare | :captcha | :js_rendered

  # pages with fewer links are likely a challenge or an empty app shell
  @min_links 10

  @cloudflare_markers ~r/<title>\s*(Just a moment|Attention Required)|cf-chl|cf_chl_opt/i
  @captcha_markers ~r/g-recaptcha|h-captcha|hcaptcha\.com|cf-turnstile|captcha-delivery|\bcaptcha\b/i
  @js_markers ~r/id=["'](__next|__nuxt|app|root)["']|ng-app|enable javascript|javascript is (disabled|required)/i

  @spec classify(%{status: integer(), headers: map(), body: term()}) :: {verdict(), String.t()}
  def classify(%{status: status, headers: headers, body: body}) do
    body = if is_binary(body), do: body, else: ""

    cond do
      header(headers, "cf-mitigated") =~ "challenge" -> cloudflare()
      status != 200 -> classify_failed(status, body)
      true -> classify_page(body)
    end
  end

  defp classify_failed(status, body) do
    cond do
      body =~ @cloudflare_markers -> cloudflare()
      body =~ @captcha_markers -> captcha()
      true -> {:http_error, "wrong response code: #{status}"}
    end
  end

  defp classify_page(body) do
    links = links_count(body)

    cond do
      links >= @min_links ->
        {:ok, "page looks parseable"}

      body =~ @cloudflare_markers ->
        cloudflare()

      body =~ @captcha_markers ->
        captcha()

      body =~ @js_markers ->
        {:js_rendered, "the page is rendered by javascript, html has no content"}

      true ->
        {:ok, "page has only #{links} links, it may be incomplete"}
    end
  end

  defp cloudflare, do: {:cloudflare, "cloudflare challenge, the page is only served to browsers"}
  defp captcha, do: {:captcha, "the page is behind a captcha"}

  defp header(headers, name), do: headers |> Map.get(name, []) |> Enum.join(",")

  defp links_count(body) do
    case Floki.parse_document(body) do
      {:ok, doc} -> doc |> Floki.find("a[href]") |> length()
      _ -> 0
    end
  end
end
