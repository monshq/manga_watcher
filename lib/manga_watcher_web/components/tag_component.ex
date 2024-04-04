defmodule MangaWatcherWeb.TagComponent do
  use Phoenix.Component

  import MangaWatcherWeb.CoreComponents

  attr :id, :integer, required: true
  attr :include, :boolean, required: true
  attr :exclude, :boolean, required: true
  attr :name, :string, doc: "tag name"

  def manga_tag(assigns) do
    ~H"""
    <span class="py-2">
      <%= if @include do %>
        <.tag_button id={@id} name={@name} state="plus" colors="bg-green-200 text-green-700" />
      <% else %>
        <%= if @exclude do %>
          <.tag_button id={@id} name={@name} state="minus" colors="bg-red-200 text-red-700" />
        <% else %>
          <.tag_button id={@id} name={@name} state="neutral" colors="bg-gray-200 text-gray-700" />
        <% end %>
      <% end %>
    </span>
    """
  end

  attr :state, :string, required: true
  attr :id, :integer, required: true
  attr :name, :string, doc: "tag name"
  attr :colors, :string

  defp tag_button(assigns) do
    # uses hero-plus hero-minus hero-stop
    # since they are not mentioned directly in the code, they have to be in the comment,
    # otherwise they're not included in the final build
    assigns =
      assign(assigns, :icons, %{
        "plus" => "plus",
        "minus" => "minus",
        "neutral" => "stop"
      })

    ~H"""
    <button phx-click="filter" phx-value-id={@id} phx-value-name={@name} phx-value-state={@state}>
      <div class={"ml-4 text-xs inline-flex items-center font-bold leading-sm uppercase px-3 py-1
              rounded-full #{@colors}"}>
        <.icon name={"hero-#{@icons[@state]}"} class="mr-1 w-3 h-3" />
        <%= @name %>
      </div>
    </button>
    """
  end
end
