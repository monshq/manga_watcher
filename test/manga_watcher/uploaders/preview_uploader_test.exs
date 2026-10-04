defmodule MangaWatcher.PreviewUploaderTest do
  use ExUnit.Case, async: true

  alias MangaWatcher.PreviewUploader

  describe "head_result/1" do
    test "treats a found object as stored" do
      assert {:ok, true} = PreviewUploader.head_result({:ok, %{status_code: 200}})
    end

    test "treats a 404 as not stored" do
      assert {:ok, false} = PreviewUploader.head_result({:error, {:http_error, 404, %{}}})
    end

    test "returns other errors instead of treating them as not stored" do
      assert {:error, :econnrefused} = PreviewUploader.head_result({:error, :econnrefused})

      assert {:error, {:http_error, 503, _}} =
               PreviewUploader.head_result({:error, {:http_error, 503, %{}}})
    end
  end

  test "stored/2 reports nil previews as not stored" do
    assert {:ok, false} = PreviewUploader.stored(nil)
  end
end
