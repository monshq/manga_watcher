defmodule MangaWatcher.PreviewUploader do
  use Waffle.Definition

  use Waffle.Ecto.Definition

  @versions [:original]

  # To add a thumbnail version:
  # @versions [:original, :thumb]

  def bucket do
    Application.fetch_env!(:waffle, :bucket)
  end

  def asset_host do
    {:system, "S3_ASSET_HOST"}
  end

  # def bucket({_file, scope}) do
  #   scope.bucket || bucket()
  # end

  # Whitelist file extensions:
  # def validate({file, _}) do
  #   file_extension = file.file_name |> Path.extname() |> String.downcase()
  #
  #   case Enum.member?(~w(.jpg .jpeg .gif .png), file_extension) do
  #     true -> :ok
  #     false -> {:error, "invalid file type"}
  #   end
  # end

  # Define a thumbnail transformation:
  # def transform(:thumb, _) do
  #   {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
  # end

  # Override the persisted filenames:
  # def filename(version, _) do
  #   version
  # end

  # Override the storage directory:
  # def storage_dir(version, {file, scope}) do
  #   "uploads/user/avatars/#{scope.id}"
  # end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "/images/default_preview.jpg"
  end

  def exists?(nil), do: false

  def exists?(name) do
    case Application.get_env(:waffle, :storage) do
      Waffle.Storage.S3 -> s3_exists?(name)
      _ -> local_exists?(name)
    end
  end

  defp s3_exists?(name) do
    case ExAws.S3.head_object(bucket(), name) |> ExAws.request() do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp local_exists?(name) do
    prefix = Application.get_env(:waffle, :storage_dir_prefix)
    dir = Application.get_env(:waffle, :storage_dir)
    File.exists?("#{prefix}/#{dir}/#{name}")
  end

  # Specify custom headers for s3 objects
  # Available options are [:cache_control, :content_disposition,
  #    :content_encoding, :content_length, :content_type,
  #    :expect, :expires, :storage_class, :website_redirect_location]
  #
  # def s3_object_headers(version, {file, scope}) do
  #   [content_type: MIME.from_path(file.file_name)]
  # end
end
