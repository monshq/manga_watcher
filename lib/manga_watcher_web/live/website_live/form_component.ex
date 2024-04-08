defmodule MangaWatcherWeb.WebsiteLive.FormComponent do
  use MangaWatcherWeb, :live_component

  alias MangaWatcher.Series

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <!-- <:subtitle>Use this form to manage website records in your database.</:subtitle> -->
      </.header>

      <.simple_form
        for={@form}
        id="website-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:base_url]} type="text" label="Base url" />
        <.input field={@form[:title_regex]} type="text" label="Title regex" />
        <.input field={@form[:links_regex]} type="text" label="Links regex" />
        <.input field={@form[:preview_regex]} type="text" label="Preview regex" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Website</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{website: website} = assigns, socket) do
    changeset = Series.change_website(website)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"website" => website_params}, socket) do
    changeset =
      socket.assigns.website
      |> Series.change_website(website_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"website" => website_params}, socket) do
    save_website(socket, socket.assigns.action, website_params)
  end

  defp save_website(socket, :edit, website_params) do
    case Series.update_website(socket.assigns.website, website_params) do
      {:ok, website} ->
        notify_parent({:saved, website})

        {:noreply,
         socket
         |> put_flash(:info, "Website updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_website(socket, :new, website_params) do
    case Series.create_website(website_params) do
      {:ok, website} ->
        notify_parent({:saved, website})

        {:noreply,
         socket
         |> put_flash(:info, "Website created successfully")
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
