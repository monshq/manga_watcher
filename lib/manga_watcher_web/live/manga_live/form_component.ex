defmodule MangaWatcherWeb.MangaLive.FormComponent do
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series
  alias MangaWatcher.Utils

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
        phx-change={if @action == :edit, do: "validate_change", else: "validate_create"}
        phx-submit="save"
      >
        <.input field={@form[:url]} label="Url" />
        <.input field={@form[:tags]} label="Tags" value={render_tags(@form)} />
        <%= if @action == :edit do %>
          <.input field={@form[:name]} label="Name" />
          <.input field={@form[:last_read_chapter]} label="Last read chapter" />
        <% end %>
        <:actions>
          <.button phx-disable-with="Saving...">Save Manga</.button>
          <%= if @action == :edit do %>
            <.button
              type="button"
              data-confirm="Are you sure?"
              phx-click="delete"
              phx-value-id={@manga.id}
            >
              Delete manga
            </.button>
          <% end %>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  defp render_tags(form) do
    case form[:tags].value do
      [%Ecto.Changeset{} | _] = v ->
        v
        |> Enum.map_join(", ", & &1.data.name)

      [%MangaWatcher.Series.Tag{} | _] = v ->
        v
        |> Enum.map_join(", ", & &1.name)

      v when is_binary(v) ->
        v

      [] ->
        []

      %Ecto.Association.NotLoaded{} ->
        ""

      v ->
        raise "unexpected value: #{inspect(v)}"
    end
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
  def handle_event("validate_change", %{"manga" => manga_params}, socket) do
    changeset =
      socket.assigns.manga
      |> Series.change_manga(manga_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("validate_create", %{"manga" => manga_params}, socket) do
    changeset =
      Series.validate_new_manga(manga_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"manga" => manga_params}, socket) do
    save_manga(socket, socket.assigns.action, manga_params)
  end

  defp save_manga(socket, :edit, manga_params) do
    params = Utils.atomize_keys(manga_params)

    case Series.update_manga(socket.assigns.manga, params) do
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
    params = Utils.atomize_keys(manga_params)

    case Series.create_manga(params) do
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
