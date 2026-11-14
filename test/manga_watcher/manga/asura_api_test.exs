defmodule MangaWatcher.Manga.AsuraApiTest do
  use ExUnit.Case, async: true

  import Mox

  alias MangaWatcher.Manga.AsuraApi

  @url "https://asurascans.com/comics/absolute-regression-f212c582"
  @api_url "https://api.asurascans.com/api/series/absolute-regression-f212c582"

  @series %{
    "series" => %{
      "title" => "Absolute Regression",
      "cover" => "https://cdn.asurascans.com/asura-images/covers/absolute-regression.webp"
    }
  }

  setup :verify_on_exit!

  defp chapter(number, premium \\ false), do: %{"number" => number, "is_premium" => premium}

  defp expect_api(series, chapters) do
    MangaWatcher.DownloaderMock
    |> expect(:download, fn @api_url -> series end)
    |> expect(:download, fn @api_url <> "/chapters" -> chapters end)
  end

  describe "handles?/1" do
    test "matches asurascans.com urls only" do
      assert AsuraApi.handles?(@url)
      assert AsuraApi.handles?("https://www.asurascans.com/comics/x")
      refute AsuraApi.handles?("https://asuracomic.net/series/x")
      refute AsuraApi.handles?("https://notasurascans.com/comics/x")
    end
  end

  describe "fetch/2" do
    test "takes the latest chapter that is not premium" do
      expect_api(
        {:ok, @series},
        {:ok, %{"data" => [chapter(127, true), chapter(126), chapter(125.5), chapter(1)]}}
      )

      assert {:ok,
              %{
                name: "Absolute Regression",
                last_chapter: 126,
                preview: "https://cdn.asurascans.com/asura-images/covers/absolute-regression.webp"
              }} = AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "decodes raw json bodies" do
      expect_api(
        {:ok, Jason.encode!(@series)},
        {:ok, Jason.encode!(%{"data" => [chapter(10.5), chapter(9)]})}
      )

      assert {:ok, %{last_chapter: 10}} = AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "unwraps series returned in data" do
      expect_api({:ok, %{"data" => @series}}, {:ok, %{"data" => [chapter(4)]}})

      assert {:ok, %{name: "Absolute Regression", last_chapter: 4}} =
               AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "uses the series slug of chapter urls" do
      expect_api({:ok, @series}, {:ok, %{"data" => [chapter(3)]}})

      assert {:ok, %{last_chapter: 3}} =
               AsuraApi.fetch(@url <> "/chapter/3", MangaWatcher.DownloaderMock)
    end

    test "fails when every chapter is premium" do
      expect_api({:ok, @series}, {:ok, %{"data" => [chapter(1, true)]}})

      assert {:error, "could not find any free chapters"} =
               AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "fails on unexpected responses" do
      MangaWatcher.DownloaderMock
      |> expect(:download, fn @api_url -> {:ok, %{"error" => "not found"}} end)

      assert {:error, "unexpected asura api response" <> _} =
               AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "passes download errors through" do
      MangaWatcher.DownloaderMock
      |> expect(:download, fn @api_url -> {:error, "wrong response code: 404"} end)

      assert {:error, "wrong response code: 404"} =
               AsuraApi.fetch(@url, MangaWatcher.DownloaderMock)
    end

    test "rejects urls that are not comics" do
      assert {:error, "not an asura comic url" <> _} =
               AsuraApi.fetch("https://asurascans.com/browse", MangaWatcher.DownloaderMock)
    end
  end
end
