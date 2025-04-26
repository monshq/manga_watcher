Mox.defmock(MangaWatcher.DownloaderMock, for: MangaWatcher.Manga.Downloader)
Mox.defmock(MangaWatcher.PageParserMock, for: MangaWatcher.Manga.PageParser)
Mox.defmock(MangaWatcher.AttrFetcherMock, for: MangaWatcher.Manga.AttrFetcher)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MangaWatcher.Repo, :manual)
