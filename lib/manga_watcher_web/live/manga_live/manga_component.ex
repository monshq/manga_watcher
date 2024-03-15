defmodule MangaWatcherWeb.MangaLive.MangaComponent do
  alias MangaWatcher.PreviewUploader
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series

  require Logger

  def edit_button(assigns) do
    ~H"""
    <.link patch={~p"/mangas/#{@manga}/edit"} phx-click={JS.push_focus()}>
      <button
        type="button"
        class="inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent text-gray-400 disabled:opacity-50 disabled:pointer-events-none dark:text-gray-500 dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
      >
        Edit
      </button>
    </.link>
    """
  end

  def manga_chapters(assigns) do
    ~H"""
    <%= if @manga.failed_updates > 5 do %>
      <span class="text-red-500 dark:text-red-500 font-bold">
        <%= @manga.last_read_chapter %> / <%= @manga.last_chapter %>
      </span>
    <% else %>
      <%= if @manga.last_chapter == @manga.last_read_chapter do %>
        <span class="text-gray-400 dark:text-gray-500">
          <%= @manga.last_read_chapter %> / <%= @manga.last_chapter %>
        </span>
      <% else %>
        <span class="text-green-600 dark:text-green-300 font-bold">
          <%= @manga.last_read_chapter %> / <%= @manga.last_chapter %>
        </span>
      <% end %>
    <% end %>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <tr id={"mangas-#{@id}"} class="bg-base-2">
      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-800 dark:text-gray-200">
        <.link href={@manga.url}>
          <div class="flex">
            <image src={PreviewUploader.url(@manga.preview)} class="w-10 h-14 mr-5" />
            <span class="flex items-center"><%= @manga.name %></span>
          </div>
        </.link>
        <dl class="md:hidden">
          <dd>
            <.manga_chapters manga={@manga} />
          </dd>
        </dl>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm md:table-cell hidden">
        <.manga_chapters manga={@manga} />
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
        <div class="flex justify-end align-center md:gap-4 gap-1 flex-col md:flex-row">
          <%= if @manga.last_chapter == @manga.last_read_chapter do %>
            <button
              disabled
              type="button"
              class="inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent text-gray-400 disabled:opacity-50 disabled:pointer-events-none dark:text-gray-500 dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
            >
              ✔️ Nothing to do
            </button>
          <% else %>
            <button
              phx-click="mark_as_read"
              phx-target={@myself}
              class="inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent text-blue-800 hover:text-blue-800 disabled:opacity-50 disabled:pointer-events-none dark:text-blue-500 dark:hover:text-blue-400 dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
            >
              ✔️ Mark as read
            </button>
          <% end %>
          <.edit_button manga={@manga} />
        </div>
      </td>
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
