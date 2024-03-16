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
        <button phx-click="filter" phx-value-id={@id} phx-value-name={@name} phx-value-state="plus">
          <div class="ml-4 text-xs inline-flex items-center font-bold leading-sm uppercase px-3 py-1
          bg-green-200 text-green-700 rounded-full">
            <.icon name="hero-plus" class="mr-1 w-3 h-3" />
            <%= @name %>
          </div>
        </button>
      <% else %>
        <%= if @exclude do %>
          <button phx-click="filter" phx-value-id={@id} phx-value-name={@name} phx-value-state="minus">
            <div class="ml-4 text-xs inline-flex items-center font-bold leading-sm uppercase px-3 py-1
            bg-red-200 text-red-700 rounded-full">
              <.icon name="hero-minus" class="mr-1 w-3 h-3" />
              <%= @name %>
            </div>
          </button>
        <% else %>
          <button
            phx-click="filter"
            phx-value-id={@id}
            phx-value-name={@name}
            phx-value-state="neutral"
          >
            <div class="ml-4 text-xs inline-flex items-center font-bold leading-sm uppercase px-3 py-1
            bg-gray-200 text-gray-700 rounded-full">
              <.icon name="hero-stop" class="mr-1 w-3 h-3" />
              <%= @name %>
            </div>
          </button>
        <% end %>
      <% end %>
    </span>
    """
  end
end
