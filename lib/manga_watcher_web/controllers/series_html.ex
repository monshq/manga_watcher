defmodule MangaWatcherWeb.SeriesHTML do
  alias MangaWatcher.Series.Manga
  use MangaWatcherWeb, :html

  embed_templates "series_html/*"

  attr :m, Manga, required: true
  def manga(assigns)

  def processing_button(assigns) do
    ~H'''
    <button
      disabled
      class="py-2 px-3 inline-flex items-center gap-x-2 text-sm font-semibold rounded-lg border border-transparent bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:pointer-events-none dark:focus:outline-none dark:focus:ring-1 dark:focus:ring-gray-600"
    >
      <svg
        class="animate-spin h-3 w-3 text-white"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>
      Processing...
    </button>
    '''
  end
end
