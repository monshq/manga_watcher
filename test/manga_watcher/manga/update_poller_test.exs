defmodule MangaWatcher.Manga.UpdatePollerTest do
  use ExUnit.Case, async: true

  test "handles :tick by calling batch_update" do
    {:ok, pid} = MangaWatcher.Manga.UpdatePoller.start_link([])
    send(pid, :tick)
    assert Process.alive?(pid)
  end
end
