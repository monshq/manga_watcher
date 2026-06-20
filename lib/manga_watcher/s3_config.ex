defmodule MangaWatcher.S3Config do
  @moduledoc false

  def endpoint_options(endpoint) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(endpoint)

    if scheme not in ["http", "https"] or is_nil(host) do
      raise ArgumentError,
            "S3_ENDPOINT must be a URL with http/https scheme and host, e.g. https://s3.amazonaws.com"
    end

    [
      scheme: "#{scheme}://",
      host: host,
      port: port,
      region: "garage"
    ]
  end
end
