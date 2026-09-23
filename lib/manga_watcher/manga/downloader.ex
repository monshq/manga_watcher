defmodule MangaWatcher.Manga.Downloader do
  alias MangaWatcher.Manga.UrlGuard

  @type response :: %{
          status: non_neg_integer(),
          url: String.t(),
          headers: %{optional(String.t()) => [String.t()]},
          body: term()
        }

  @behaviour __MODULE__
  @callback download(url :: String.t()) :: {:ok, binary()} | {:error, term()}
  @callback download(url :: String.t(), referer :: String.t()) ::
              {:ok, binary()} | {:error, term()}
  @callback fetch(url :: String.t(), opts :: keyword()) :: {:ok, response()} | {:error, term()}

  @spec download(String.t(), String.t()) :: {:ok, binary} | {:error, atom}
  def download(url, referer \\ "") do
    case fetch(url, referer: referer) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "wrong response code: #{status}"}

      {:error, e} ->
        {:error, e}
    end
  end

  @doc """
  Performs the same request as `download/2`, but returns the whole response
  regardless of its status. `url` in the response is the one after redirects.

  Options:
    * `:referer` - value of the Referer header, empty by default
    * `:guard` - reject urls (including redirects) pointing to private addresses
  """
  @spec fetch(String.t(), keyword()) :: {:ok, response()} | {:error, term()}
  def fetch(url, opts \\ []) do
    request =
      Req.new(
        url: url,
        headers: [{"Referer", opts[:referer] || ""}, {"User-Agent", "MangaWatcher/1.0.0"}],
        redirect_trusted: true
      )

    request =
      if opts[:guard] do
        Req.Request.append_request_steps(request, url_guard: &UrlGuard.req_step/1)
      else
        request
      end

    case Req.run(request) do
      {request, %Req.Response{} = resp} ->
        {:ok,
         %{
           status: resp.status,
           url: URI.to_string(request.url),
           headers: resp.headers,
           body: resp.body
         }}

      {_request, exception} ->
        {:error, exception}
    end
  rescue
    e -> {:error, e}
  end
end
