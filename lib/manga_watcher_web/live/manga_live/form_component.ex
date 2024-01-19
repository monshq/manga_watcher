defmodule MangaWatcherWeb.MangaLive.FormComponent do
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.simple_form
        for={@form}
        id="manga-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <:actions>
          <.button phx-disable-with="Saving...">Save Manga</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{manga: manga} = assigns, socket) do
    changeset = Series.change_manga(manga)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"manga" => manga_params}, socket) do
    changeset =
      socket.assigns.manga
      |> Series.change_manga(manga_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"manga" => manga_params}, socket) do
    save_manga(socket, socket.assigns.action, manga_params)
  end

  defp save_manga(socket, :edit, manga_params) do
    case Series.update_manga(socket.assigns.manga, manga_params) do
      {:ok, manga} ->
        notify_parent({:saved, manga})

        {:noreply,
         socket
         |> put_flash(:info, "Manga updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_manga(socket, :new, manga_params) do
    case Series.create_manga(manga_params) do
      {:ok, manga} ->
        notify_parent({:saved, manga})

        {:noreply,
         socket
         |> put_flash(:info, "Manga created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
