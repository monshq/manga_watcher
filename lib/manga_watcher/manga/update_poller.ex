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
    with_job_metadata(fn ->
      Series.list_mangas_for_update() |> Updater.batch_update()
    end)

    Process.send_after(self(), :tick, @interval * 1000)
    {:noreply, state}
  end

  defp with_job_metadata(fun) do
    original_metadata = Logger.metadata()

    Logger.metadata(job_id: generate_job_id())

    try do
      fun.()
    after
      Logger.reset_metadata(original_metadata)
    end
  end

  defp generate_job_id do
    alphabet = ~c"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"

    for _ <- 1..6, into: "" do
      <<Enum.random(alphabet)>>
    end
  end
end
