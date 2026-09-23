defmodule MangaWatcher.Sources.BlockDetectorTest do
  use ExUnit.Case, async: true

  alias MangaWatcher.Sources.BlockDetector

  defp classify(status, body, headers \\ %{}) do
    {verdict, _reason} = BlockDetector.classify(%{status: status, headers: headers, body: body})
    verdict
  end

  defp links(n), do: Enum.map_join(1..n, &~s(<a href="/chapter-#{&1}">#{&1}</a>))

  test "fixture pages are parseable" do
    for name <- ["asuratoon", "batoto", "manhwalike"] do
      body = File.read!("test/support/fixtures/website_pages/#{name}.html")
      assert classify(200, body) == :ok
    end
  end

  test "detects cloudflare challenges" do
    assert classify(403, "<html><head><title>Just a moment...</title></head></html>") ==
             :cloudflare

    assert classify(503, "<script>window._cf_chl_opt={}</script>") == :cloudflare
    assert classify(200, "<html></html>", %{"cf-mitigated" => ["challenge"]}) == :cloudflare
  end

  test "does not treat cloudflare scripts on normal pages as a challenge" do
    body =
      ~s(<script src="/cdn-cgi/challenge-platform/scripts/jsd/main.js"></script>) <> links(20)

    assert classify(200, body) == :ok
  end

  test "detects captchas" do
    assert classify(403, ~s(<div class="g-recaptcha"></div>)) == :captcha
    assert classify(200, ~s(<div class="cf-turnstile"></div>)) == :captcha
  end

  test "ignores captchas in comment forms of normal pages" do
    assert classify(200, ~s(<div class="g-recaptcha"></div>) <> links(20)) == :ok
  end

  test "detects javascript rendered pages" do
    assert classify(200, ~s(<body><div id="__next"></div><script src="/app.js"></script></body>)) ==
             :js_rendered

    assert classify(200, "<noscript>Please enable JavaScript to continue</noscript>") ==
             :js_rendered
  end

  test "reports other error statuses" do
    assert classify(404, "not found") == :http_error
    assert classify(500, "") == :http_error
  end
end
