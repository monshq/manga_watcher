defmodule MangaWatcher.Manga.UrlGuard do
  @moduledoc """
  Rejects urls that point to loopback, private or link-local addresses, so that
  urls supplied through the agent api can't be used to reach internal services.
  """

  defmodule BlockedError do
    defexception [:url, :reason]

    @impl true
    def message(%{url: url, reason: reason}), do: "blocked #{url}: #{reason}"
  end

  @spec check(String.t() | URI.t()) :: :ok | {:error, String.t()}
  def check(url) when is_binary(url), do: url |> URI.parse() |> check()

  def check(%URI{scheme: scheme}) when scheme not in ["http", "https"],
    do: {:error, "only http and https urls are allowed"}

  def check(%URI{host: host}) when host in [nil, ""], do: {:error, "url has no host"}

  def check(%URI{host: host}) do
    if host |> resolve() |> Enum.any?(&private?/1) do
      {:error, "host #{host} resolves to a private address"}
    else
      :ok
    end
  end

  @doc """
  Req request step that halts the request when its url is blocked. Req runs
  request steps again for every redirect, so redirects are checked as well.
  """
  def req_step(%Req.Request{url: url} = request) do
    case check(url) do
      :ok ->
        request

      {:error, reason} ->
        Req.Request.halt(request, %BlockedError{url: URI.to_string(url), reason: reason})
    end
  end

  defp resolve(host) do
    host = String.trim(host, "[") |> String.trim("]") |> String.to_charlist()

    case :inet.parse_address(host) do
      {:ok, ip} ->
        [ip]

      {:error, _} ->
        Enum.flat_map([:inet, :inet6], &lookup(host, &1))
    end
  end

  defp lookup(host, family) do
    case :inet.getaddrs(host, family) do
      {:ok, ips} -> ips
      {:error, _} -> []
    end
  end

  defp private?({0, _, _, _}), do: true
  defp private?({10, _, _, _}), do: true
  defp private?({127, _, _, _}), do: true
  defp private?({169, 254, _, _}), do: true
  defp private?({192, 168, _, _}), do: true
  defp private?({172, b, _, _}) when b in 16..31, do: true
  defp private?({100, b, _, _}) when b in 64..127, do: true
  defp private?({a, _, _, _}) when a >= 224, do: true
  defp private?({_, _, _, _}), do: false

  defp private?({0, 0, 0, 0, 0, 0, 0, a}) when a in [0, 1], do: true
  defp private?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}), do: private?(ipv4(hi, lo))
  defp private?({a, _, _, _, _, _, _, _}) when Bitwise.band(a, 0xFE00) == 0xFC00, do: true
  defp private?({a, _, _, _, _, _, _, _}) when Bitwise.band(a, 0xFFC0) == 0xFE80, do: true
  defp private?({_, _, _, _, _, _, _, _}), do: false

  defp ipv4(hi, lo) do
    {Bitwise.bsr(hi, 8), Bitwise.band(hi, 0xFF), Bitwise.bsr(lo, 8), Bitwise.band(lo, 0xFF)}
  end
end
