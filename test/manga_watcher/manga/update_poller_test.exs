defmodule MangaWatcher.Manga.UpdatePollerTest do
  use MangaWatcher.DataCase

  import ExUnit.CaptureLog

  setup do
    original_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: original_level)
    end)
  end

  test "handles :tick by calling batch_update with job metadata" do
    {:ok, pid} = MangaWatcher.Manga.UpdatePoller.start_link([])

    log =
      capture_log([level: :info], fn ->
        send(pid, :tick)
        :sys.get_state(pid)
      end)

    assert Process.alive?(pid)
    assert log =~ ~r/job_id=[ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789]{6}/
    assert log =~ "starting update of outdated mangas"
    assert log =~ "finished updating mangas"
  end
end
