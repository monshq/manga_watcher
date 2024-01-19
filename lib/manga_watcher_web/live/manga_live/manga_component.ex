defmodule MangaWatcherWeb.MangaLive.MangaComponent do
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <tr class="bg-white dark:bg-gray-800">
      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-800 dark:text-gray-200">
        <.link href={@manga.url}><%= @manga.name %></.link>
      </td>
      <%= if @manga.last_chapter == @manga.last_read_chapter do %>
        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-400 dark:text-gray-500">
          <%= @manga.last_read_chapter %> / <%= @manga.last_chapter %>
        </td>
        <td class="px-6 py-4 whitespace-nowrap text-end text-sm font-medium">
          <button
            disabled
            type="button"
            class="inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent text-gray-400 disabled:opacity-50 disabled:pointer-events-none dark:text-gray-500 dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
          >
            ✔️ Nothing to do
          </button>
        </td>
      <% else %>
        <td class="px-6 py-4 whitespace-nowrap text-sm text-green-600 dark:text-green-300 font-bold">
          <%= @manga.last_read_chapter %> / <%= @manga.last_chapter %>
        </td>
        <td class="px-6 py-4 whitespace-nowrap text-end text-sm font-medium">
          <button
            phx-click="mark_as_read"
            phx-target={@myself}
            class="inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent text-blue-800 hover:text-blue-800 disabled:opacity-50 disabled:pointer-events-none dark:text-blue-500 dark:hover:text-blue-400 dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
          >
            ✔️ Mark as read
          </button>
        </td>
      <% end %>
    </tr>
    """
  end

  @impl true
  def handle_event("mark_as_read", _value, socket) do
    manga = socket.assigns.manga
    Logger.info("marking manga #{manga.name} as read")
    {:ok, manga} = Series.update_manga(manga, %{last_read_chapter: manga.last_chapter})
    {:noreply, assign(socket, :manga, manga)}
  end
end
