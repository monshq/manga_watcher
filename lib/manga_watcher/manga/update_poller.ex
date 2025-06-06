defmodule MangaWatcher.Manga.UpdatePoller do
  use GenServer

  alias MangaWatcher.Series
  alias MangaWatcher.Manga.Updater

  # seconds
  @interval 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :no_state, opts)
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :tick, @interval * 1000)
    {:ok, :no_state}
  end

  @impl true
  def handle_info(:tick, state) do
    Series.list_mangas_for_update() |> Updater.batch_update()
    Process.send_after(self(), :tick, @interval * 1000)
    {:noreply, state}
  end
end
