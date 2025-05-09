defmodule MangaWatcherWeb.MangaLive.MangaComponent do
  alias MangaWatcher.PreviewUploader
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.UserMangas

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
    <%= cond do %>
      <% @manga.failed_updates > 5 -> %>
        <span class="text-red-500 dark:text-red-500 font-bold">
          <%= last_read_chapter(@manga) %> / <%= @manga.last_chapter %>
        </span>
      <% @manga.last_chapter <= last_read_chapter(@manga) -> %>
        <span class="text-gray-400 dark:text-gray-500">
          <%= last_read_chapter(@manga) %> / <%= @manga.last_chapter %>
        </span>
      <% true -> %>
        <span class="text-green-600 dark:text-green-300 font-bold">
          <%= last_read_chapter(@manga) %> / <%= @manga.last_chapter %>
        </span>
    <% end %>
    """
  end

  def last_read_chapter(%Manga{} = manga) do
    hd(manga.user_mangas).last_read_chapter
  end

  @impl true
  def render(assigns) do
    ~H"""
    <card id={@id} class="bg-base-2 flex flex-row">
      <.link
        target="_blank"
        href={@manga.url}
        class="basis-[30%] grow-0 shrink-0 mr-3 flex aspect-[10/14]"
      >
        <image src={PreviewUploader.url(@manga.preview)} class="object-cover" />
      </.link>
      <div class="grow flex flex-col justify-between">
        <div>
          <.link target="_blank" href={@manga.url} class="font-medium dark:text-white">
            <%= @manga.name %>
          </.link>
          <dl class="">
            <dd>
              <.manga_chapters manga={@manga} />
            </dd>
          </dl>
        </div>
        <div class="mb-2 mr-2 flex justify-end md:gap-4 gap-1 flex-row whitespace-nowrap">
          <%= if @manga.last_chapter != last_read_chapter(@manga) do %>
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
      </div>
    </card>
    """
  end

  @impl true
  def handle_event("mark_as_read", _value, socket) do
    manga = socket.assigns.manga
    Logger.info("marking manga #{manga.name} as read")

    {:ok, user_manga} =
      UserMangas.update_user_manga(hd(manga.user_mangas), %{last_read_chapter: manga.last_chapter})

    manga = %{manga | user_mangas: [user_manga]}

    {:noreply, assign(socket, :manga, manga)}
  end
end
