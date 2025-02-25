defmodule MangaWatcherWeb.WebsiteLive.Index do
  use MangaWatcherWeb, :live_view

  alias MangaWatcher.Series
  alias MangaWatcher.Series.Website

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :websites, Series.list_websites())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Website")
    |> assign(:website_counters, Series.website_counts())
    |> assign(:website, Series.get_website!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Website")
    |> assign(:website_counters, Series.website_counts())
    |> assign(:website, %Website{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Websites")
    |> assign(:website_counters, Series.website_counts())
    |> assign(:website, nil)
  end

  @impl true
  def handle_info({MangaWatcherWeb.WebsiteLive.FormComponent, {:saved, website}}, socket) do
    {:noreply, stream_insert(socket, :websites, website)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    website = Series.get_website!(id)
    {:ok, _} = Series.delete_website(website)

    {:noreply, stream_delete(socket, :websites, website)}
  end

  def website_status(assigns) do
    ~H"""
    <span class="font-bold">
      <%= cond do %>
        <% @counter.total == 0 -> %>
          Unused
        <% @counter.total == @counter.broken -> %>
          <span class="text-red-500">
            Broken <%= "(#{@counter.total})" %>
          </span>
        <% @counter.broken == 0 -> %>
          <span class="text-green-500">
            Healthy <%= "(#{@counter.total})" %>
          </span>
        <% true -> %>
          <span class="text-yellow-500">
            Partially working <%= "(#{@counter.total - @counter.broken} / #{@counter.total})" %>
          </span>
      <% end %>
    </span>
    """
  end
end
