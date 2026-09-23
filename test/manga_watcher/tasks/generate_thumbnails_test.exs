defmodule MangaWatcher.Tasks.GenerateThumbnailsTest do
  use MangaWatcher.DataCase, async: true

  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.PreviewUploader
  alias MangaWatcher.Tasks.GenerateThumbnails

  @moduletag :capture_log

  test "generates thumbnails for stored previews that have none" do
    storage_dir =
      Path.join(
        Application.get_env(:waffle, :storage_dir_prefix),
        PreviewUploader.storage_dir(:original, nil)
      )

    name = "legacy_preview_#{System.unique_integer([:positive])}"
    File.mkdir_p!(storage_dir)
    File.cp!("test/support/fixtures/preview.png", Path.join(storage_dir, "#{name}.png"))

    on_exit(fn ->
      File.rm(Path.join(storage_dir, "#{name}.png"))
      File.rm(Path.join(storage_dir, "#{name}_thumb.webp"))
    end)

    manga_fixture(%{preview: "#{name}.png"})

    refute PreviewUploader.exists?("#{name}.png", :thumb)

    GenerateThumbnails.run()

    assert PreviewUploader.exists?("#{name}.png", :thumb)
    assert PreviewUploader.url("#{name}.png", :thumb) =~ "#{name}_thumb.webp"
  end
end
