defmodule MangaWatcher.PreviewUploader do
  use Waffle.Definition

  use Waffle.Ecto.Definition

  # covers are shown ~100-175px wide, 400px keeps them sharp on 2-3x screens
  @versions [:original, :thumb]
  @thumb_width 400

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

  # [0] takes the first frame, otherwise animated gifs produce a file per frame
  def transform(:thumb, _) do
    {:convert,
     fn input, output ->
       ["#{input}[0]", "-strip", "-thumbnail", "#{@thumb_width}x>", "-quality", "80", output]
     end, :webp}
  end

  def filename(:thumb, {file, _}), do: base_name(file.file_name) <> "_thumb"
  def filename(_version, {file, _}), do: base_name(file.file_name)

  defp base_name(file_name), do: Path.basename(file_name, Path.extname(file_name))

  # Override the storage directory:
  # def storage_dir(version, {file, scope}) do
  #   "uploads/user/avatars/#{scope.id}"
  # end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "/images/default_preview.jpg"
  end

  def exists?(name, version \\ :original)

  def exists?(nil, _version), do: false

  def exists?(name, version) do
    key = key(name, version)

    case Application.get_env(:waffle, :storage) do
      Waffle.Storage.S3 ->
        match?({:ok, _}, ExAws.S3.head_object(bucket(), key) |> ExAws.request())

      _ ->
        File.exists?(local_path(key))
    end
  end

  @doc "Reads the stored original, used to regenerate versions for existing previews."
  def read(name) do
    key = key(name, :original)

    case Application.get_env(:waffle, :storage) do
      Waffle.Storage.S3 ->
        with {:ok, %{body: body}} <- ExAws.S3.get_object(bucket(), key) |> ExAws.request() do
          {:ok, body}
        end

      _ ->
        File.read(local_path(key))
    end
  end

  # same layout as waffle uses when storing: <storage_dir>/<versioned file name>
  defp key(name, version) do
    file_name =
      Waffle.Definition.Versioning.resolve_file_name(
        __MODULE__,
        version,
        {%{file_name: name}, nil}
      )

    Path.join(storage_dir(version, nil), file_name)
  end

  defp local_path(key), do: Path.join(storage_dir_prefix(), key)

  # without it objects are served as binary/octet-stream
  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end
