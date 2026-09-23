defmodule MangaWatcherWeb.Api.AgentController do
  @moduledoc """
  Api used by the Hermes agent to add and repair manga websites. It has no
  authentication, access from outside is blocked by the reverse proxy.
  """
  use MangaWatcherWeb, :controller

  alias MangaWatcher.Sources

  @max_test_urls 10

  def index(conn, _params) do
    json(conn, %{sources: Sources.list()})
  end

  def probe(conn, %{"url" => url}) when is_binary(url) do
    case Sources.probe(url) do
      {:ok, result} -> json(conn, result)
      {:error, e} -> error(conn, 422, message(e))
    end
  end

  def probe(conn, _params), do: error(conn, 400, "url is required")

  def test(conn, %{"urls" => urls, "selectors" => selectors}) do
    with :ok <- validate_test_urls(urls),
         {:ok, selectors} <- parse_selectors(selectors) do
      reports = Sources.test(urls, selectors)
      json(conn, %{ok: Enum.all?(reports, & &1.ok), reports: reports})
    else
      {:error, msg} -> error(conn, 400, msg)
    end
  end

  def test(conn, _params), do: error(conn, 400, "urls and selectors are required")

  def save(conn, %{"host" => host} = params) do
    case parse_selectors(params["selectors"]) do
      {:ok, selectors} -> save_source(conn, host, selectors, params)
      {:error, msg} -> error(conn, 400, msg)
    end
  end

  defp save_source(conn, host, selectors, params) do
    case Sources.save(host, selectors, params["verified_urls"],
           confirm: params["confirm"] == true
         ) do
      {:ok, action, source, reports} ->
        conn
        |> put_status(if action == :created, do: :created, else: :ok)
        |> json(%{action: action, source: source, reports: reports})

      {:error, :tests_failed, reports} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "selectors failed verification", reports: reports})

      {:error, :needs_confirmation, diff} ->
        message = "source #{host} exists, updating it requires confirm: true"
        conn |> put_status(:conflict) |> json(Map.put(diff, :error, message))

      {:error, :invalid_urls, msg} ->
        error(conn, 400, msg)

      {:error, %Ecto.Changeset{} = changeset} ->
        error(conn, 422, changeset_errors(changeset))
    end
  end

  defp validate_test_urls(urls) do
    cond do
      not is_list(urls) or urls == [] or not Enum.all?(urls, &is_binary/1) ->
        {:error, "urls must be a non-empty list of strings"}

      length(urls) > @max_test_urls ->
        {:error, "at most #{@max_test_urls} urls can be tested at once"}

      true ->
        :ok
    end
  end

  defp parse_selectors(%{"title" => title, "links" => links, "preview" => preview} = selectors) do
    if Enum.all?([title, links, preview], &(is_binary(&1) and String.trim(&1) != "")) do
      {:ok, %{title: title, links: links, preview: preview}}
    else
      {:error, "selectors must be non-empty strings, got: #{inspect(selectors)}"}
    end
  end

  defp parse_selectors(_selectors),
    do: {:error, "selectors must be an object with title, links and preview"}

  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp message(e) when is_exception(e), do: Exception.message(e)
  defp message(e) when is_binary(e), do: e
  defp message(e), do: inspect(e)

  defp error(conn, status, message) do
    conn |> put_status(status) |> json(%{error: message})
  end
end
